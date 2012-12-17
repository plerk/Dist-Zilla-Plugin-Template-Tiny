package Dist::Zilla::Plugin::Template::Tiny;

use Moose;
use v5.10;
use Template::Tiny;
use Dist::Zilla::File::InMemory;

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
with 'Dist::Zilla::Role::FileInjector';

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

which generates a C<Foo.pm> for each C<foo.pm.tt>.

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
  is  => 'ro',
  isa => 'ArrayRef[Str]',
);

=head1 METHODS

=head2 $plugin-E<gt>gather_files( $arg )

This method processes the TT files and injects the results into your dist.

=cut

sub gather_files
{
  my($self, $arg) = @_;
  
  my $tt = Template::Tiny->new( TRIM => $self->trim );

  my $list =
    defined $self->finder 
    ? $self->zilla->find_files($self->finder)
    : [ grep { $_->name =~ /\.tt$/ } @{ $self->zilla->files } ];

  my $vars = $self->_vars;
    
  foreach my $template (@$list)
  {
 
    my $file = Dist::Zilla::File::InMemory->new(
      name    => do {
        my $filename = $template->name;
        eval q{ $filename =~ s} . $self->output_regex;
        $filename;
      },
      content => do {
        my $output = '';
        my $input = $template->content;
        $tt->process(\$input, $vars, \$output);
        $output;
      },
    );
    
    $self->add_file($file);
  }
}

sub _vars
{
  my($self) = @_;
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
  return \%vars;
}

=head2 $plugin->mvp_multivalue_args

Returns list of attributes that can be specified multiple times.

=cut

sub mvp_multivalue_args { qw(var) }

__PACKAGE__->meta->make_immutable;

1;
