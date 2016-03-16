# Dist::Zilla::Plugin::Template::Tiny

process template files in your dist using Template::Tiny

# SYNOPSIS

    [Template::Tiny]

# DESCRIPTION

This plugin processes TT template files included in your distribution using
[Template::Tiny](https://metacpan.org/pod/Template::Tiny) (a subset of [Template Toolkit](https://metacpan.org/pod/Template)).  It provides
a single variable `dzil` which is an instance of [Dist::Zilla](https://metacpan.org/pod/Dist::Zilla) which can
be queried for things like the version or name of the distribution.

# ATTRIBUTES

## finder

Specifies a [FileFinder](https://metacpan.org/pod/Dist::Zilla::Role::FileFinder) for the TT files that
you want processed.  If not specified all TT files with the .tt extension will
be processed.

    [FileFinder::ByName / TTFiles]
    file = *.tt
    [Template::Tiny]
    finder = TTFiles

## output\_regex

Regular expression substitution used to generate the output filenames.  By default
this is

    [Template::Tiny]
    output_regex = /\.tt$//

which generates a `Foo.pm` for each `Foo.pm.tt`.

## trim

Passed as `TRIM` to the constructor for [Template::Tiny](https://metacpan.org/pod/Template::Tiny).

## var

Specify additional variables for use by your template.  The format is _name_ = _value_
so to specify foo = 1 and bar = 'hello world' you would include this in your dist.ini:

    [Template::Tiny]
    var = foo = 1
    var = bar = hello world

## replace

If set to a true value, existing files in the source tree will be replaced, if necessary.

## prune

If set to a true value, the original template files will NOT be included in the built distribution.

# EXAMPLES

Why would you even need templates that get processed when you build your distribution
anyway?  There are many useful [Dist::Zilla](https://metacpan.org/pod/Dist::Zilla) plugins that provide mechanisms for
manipulating POD and Perl after all.  I work on Perl distributions that are web apps
that include CSS and JavaScript, and I needed a way to get the distribution version into
the JavaScript.  This seemed to be the clearest and most simple way to go about this.

First of all, I have a share directory called public that gets installed via 
[\[ShareDir\]](https://metacpan.org/pod/Dist::Zilla::Plugin::ShareDir).

    [ShareDir]
    dir = public

Next I use this plugin to process .js.tt files in the appropriate directory, so that
.js files are produced.

    [FileFinder::ByName / JavaScriptTTFiles]
    dir = public/js
    file = *.js.tt
    [Template::Tiny]
    finder = JavaScriptTTFiles
    replace = 1
    prune = 1

Finally, I create a version.js.tt file

    if(PlugAuth === undefined) var PlugAuth = {};
    if(PlugAuth.UI === undefined) PlugAuth.UI = {};
    
    PlugAuth.UI.Name = 'PlugAuth WebUI';
    PlugAuth.UI.VERSION = '[% dzil.version %]';

which gets processed and used when the distribution is built and later installed.  I also
create a version.js file in the same directory so that I can use the distribution without
having to build it.

    if(PlugAuth === undefined) var PlugAuth = {};
    if(PlugAuth === undefined) PlugAuth.UI = {};
    
    PlugAuth.UI.Name = 'PlugAuth WebUI';
    PlugAuth.UI.VERSION = 'dev';

Now when I run it out of the checked out distribution I get `dev` reported as the version
and the actual version reported when I run from an installed copy.

There are probably other use cases and ways to get yourself into trouble.

# AUTHOR

Graham Ollis &lt;plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
