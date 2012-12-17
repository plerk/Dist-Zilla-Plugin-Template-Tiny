package Dist::Zilla::Plugin::Template::Tiny;

use Moose;
use v5.10;
use Template::Tiny;
use Dist::Zilla::File::InMemory;
use List::Util qw(first);

# ABSTRACT: process template files in your dist using Template::Tiny
# VERSION

=head1 SYNOPSIS

 [Template::Tiny]

=head1 DESCRIPTION

This plugin processes TT template files included in your distribution using
L<Template::Tiny> (a subset of L<Template Toolkit|Template>).  It provides
a single variable C<dzil> which is an instance of L<Dist::Zilla> which can
be queried for things like the version or name of the distribution.

=cut

with 'Dist::Zilla::Role::FileGatherer';
with 'Dist::Zilla::Role::FileMunger';
with 'Dist::Zilla::Role::FileInjector';
with 'Dist::Zilla::Role::FilePruner';

use namespace::autoclean;

=head1 ATTRIBUTES

=head2 finder

Specifies a L<FileFinder|Dist::Zilla::Role::FileFinder> for the TT files that
you want processed.  If not specified all TT files with the .tt extension will
be processed.

 [FileFinder::ByName / TTFiles]
 file = *.tt
 [Template::Tiny]
 finder = TTFiles

=cut

has finder => (
  is  => 'ro',
  isa => 'Str',
);

=head2 output_regex

Regular expression substitution used to generate the output filenames.  By default
this is

 [Template::Tiny]
 output_regex = /\.tt$//

which generates a C<Foo.pm> for each C<Foo.pm.tt>.

=cut

has output_regex => (
  is      => 'ro',
  isa     => 'Str',
  default => '/\.tt$//',
);

=head2 trim

Passed as C<TRIM> to the constructor for L<Template::Tiny>.

=cut

has trim => (
  is      => 'ro',
  isa     => 'Bool',
  default => 0,
);

=head2 var

Specify additional variables for use by your template.  The format is I<name> = I<value>
so to specify foo = 1 and bar = 'hello world' you would include this in your dist.ini:

 [Template::Tiny]
 var = foo = 1
 var = bar = hello world

=cut

has var => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  default => sub { [] },
);

=head2 replace

If set to a true value, existing files in the source tree will be replaced, if necessary.

=cut

has replace => (
  is      => 'ro',
  isa     => 'Bool',
  default => 0,
);

has _munge_list => (
  is      => 'ro',
  isa     => 'ArrayRef[Dist::Zilla::Role::File]',
  default => sub { [] },
);

has _tt => (
  is      => 'ro',
  isa     => 'Template::Tiny',
  lazy    => 1,
  default => sub {
    Template::Tiny->new( TRIM => shift->trim );
  },
);

=head2 prune

If set to a true value, the original template files will NOT be included in the built distribution.

=cut

has prune => (
  is      => 'ro',
  isa     => 'Bool',
  default => 0,
);

has _prune_list => (
  is      => 'ro',
  isa     => 'ArrayRef[Dist::Zilla::Role::File]',
  default => sub { [] },
);

=head1 METHODS

=head2 $plugin-E<gt>gather_files( $arg )

This method processes the TT files and injects the results into your dist.

=cut

sub gather_files
{
  my($self, $arg) = @_;

  my $list =
    defined $self->finder 
    ? $self->zilla->find_files($self->finder)
    : [ grep { $_->name =~ /\.tt$/ } @{ $self->zilla->files } ];

  foreach my $template (@$list)
  {
    my $filename = do {
      my $filename = $template->name;
      eval q{ $filename =~ s} . $self->output_regex;
      $self->log("processing " . $template->name . " => $filename");
      $filename;
    };
    my $exists = first { $_->name eq $filename } @{ $self->zilla->files };
    if($self->replace && $exists)
    {
      push @{ $self->_munge_list }, [ $template, $exists ];
    }
    else
    {
      my $file = Dist::Zilla::File::InMemory->new(
        name    => $filename,
        content => do {
          my $output = '';
          my $input = $template->content;
          $self->_tt->process(\$input, $self->_vars, \$output);
          $output;
        },
      );
      $self->add_file($file);
      push @{ $self->_prune_list }, $template if $self->prune;
    }
  }
}

sub _vars
{
  my($self) = @_;
  
  unless(defined $self->{_vars})
  {
  
    my %vars = ( dzil => $self->zilla );
    foreach my $var (@{ $self->var })
    {
      if($var =~ /^(.*?)=(.*)$/)
      {
        my $name = $1;
        my $value = $2;
        for($name,$value) {
          s/^\s+//;
          s/\s+$//;
        }
        $vars{$name} = $value;
      }
    }
    
    $self->{_vars} = \%vars;
  }
  
  return $self->{_vars};
}

=head2 $plugin-E<gt>munge_files

This method is used to munge files that need to be replaced instead of injected.

=cut

sub munge_files
{
  my($self) = @_;
  foreach my $item (@{ $self->_munge_list })
  {
    my($template,$file) = @$item;
    my $output = '';
    my $input = $template->content;
    $self->_tt->process(\$input, $self->_vars, \$output);
    $file->content($output);
  }
  $self->prune_files;
}

=head2 $plugin-E<gt>prune_files

This method is used to prune the original templates if the C<prune> attribute is
set.

=cut

sub prune_files
{
  my($self) = @_;
  foreach my $template (@{ $self->_prune_list })
  {
    $self->log("pruning " . $template->name);
    $self->zilla->prune_file($template);
  }
  
  @{ $self->_prune_list } = ();
}

=head2 $plugin-E<gt>mvp_multivalue_args

Returns list of attributes that can be specified multiple times.

=cut

sub mvp_multivalue_args { qw(var) }

__PACKAGE__->meta->make_immutable;

1;
