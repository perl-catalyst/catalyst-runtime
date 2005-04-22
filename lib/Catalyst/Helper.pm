package Catalyst::Helper;

use strict;
use base 'Class::Accessor::Fast';
use Config;
use File::Spec;
use File::Path;
use IO::File;
use FindBin;
use Template;
use Catalyst;

my %cache;

=head1 NAME

Catalyst::Helper - Bootstrap a Catalyst application

=head1 SYNOPSIS

See L<Catalyst::Manual::Intro>

=head1 DESCRIPTION

Bootstrap a Catalyst application. Autogenerates scripts

=head2 METHODS

=head3 get_file

Slurp file from DATA.

=cut

sub get_file {
    my ( $self, $class, $file ) = @_;
    unless ( $cache{$class} ) {
        local $/;
        $cache{$class} = eval "package $class; <DATA>";
    }
    my $data = $cache{$class};
    my @files = split /^__(.+)__\n/m, $data;
    shift @files;
    while (@files) {
        my ( $name, $content ) = splice @files, 0, 2;
        return $content if $name eq $file;
    }
    return 0;
}

=head3 mk_app

Create the main application skeleton.

=cut

sub mk_app {
    my ( $self, $name ) = @_;
    return 0 if $name =~ /[^\w\:]/;
    $self->{name} = $name;
    $self->{dir}  = $name;
    $self->{dir} =~ s/\:\:/-/g;
    $self->{appprefix} = lc $self->{dir};
    $self->{appprefix} =~ s/-/_/g;
    $self->{startperl} = $Config{startperl};
    $self->{scriptgen} = $Catalyst::CATALYST_SCRIPT_GEN;
    $self->{author}    = $self->{author} = $ENV{'AUTHOR'}
      || eval { @{ [ getpwuid($<) ] }[6] } || 'A clever guy';
    $self->_mk_dirs;
    $self->_mk_appclass;
    $self->_mk_build;
    $self->_mk_makefile;
    $self->_mk_readme;
    $self->_mk_changes;
    $self->_mk_apptest;
    $self->_mk_cgi;
    $self->_mk_fcgi;
    $self->_mk_server;
    $self->_mk_test;
    $self->_mk_create;
    return 1;
}

=head3 mk_component

This method is called by create.pl to make new components
for your application.

=cut

sub mk_component {
    my $self = shift;
    my $app  = shift;
    $self->{app} = $app;
    $self->{author} = $self->{author} = $ENV{'AUTHOR'}
      || eval { @{ [ getpwuid($<) ] }[6] } || 'A clever guy';
    $self->{base} = File::Spec->catdir( $FindBin::Bin, '..' );
    unless ( $_[0] =~ /^model|m|view|v|controller|c\$/i ) {
        my $helper = shift;
        my @args   = @_;
        my $class  = "Catalyst::Helper::$helper";
        eval "require $class";
        die qq/Couldn't load helper "$class", "$@"/ if $@;
        if ( $class->can('mk_stuff') ) {
            return 1 unless $class->mk_stuff( $self, @args );
        }
    }
    else {
        my $type   = shift;
        my $name   = shift || "Missing name for model/view/controller";
        my $helper = shift ;
        my @args   = @_;
        return 0 if $name =~ /[^\w\:]/;
        $type = 'M' if $type =~ /model|m/i;
        $type = 'V' if $type =~ /view|v/i;
        $type = 'C' if $type =~ /controller|c/i;
        $self->{type}  = $type;
        $self->{name}  = $name;
        $self->{class} = "$app\::$type\::$name";

        # Class
        my $appdir = File::Spec->catdir( split /\:\:/, $app );
        my $path =
          File::Spec->catdir( $FindBin::Bin, '..', 'lib', $appdir, $type );
        my $file = $name;
        if ( $name =~ /\:/ ) {
            my @path = split /\:\:/, $name;
            $file = pop @path;
            $path = File::Spec->catdir( $path, @path );
            mkpath $path;
        }
        $file = File::Spec->catfile( $path, "$file.pm" );
        $self->{file} = $file;

        # Test
        $self->{test_dir} = File::Spec->catdir( $FindBin::Bin, '..', 't' );
        $self->{test}     = $self->next_test;

        # Helper
        if ($helper) {
            my $comp = 'Model';
            $comp = 'View'       if $type eq 'V';
            $comp = 'Controller' if $type eq 'C';
            my $class = "Catalyst::Helper::$comp\::$helper";
            eval "require $class";
            die qq/Couldn't load helper "$class", "$@"/ if $@;
            if ( $class->can('mk_compclass') ) {
                return 1 unless $class->mk_compclass( $self, @args );
            }
            else { return 1 unless $self->_mk_compclass }

            if ( $class->can('mk_comptest') ) {
                $class->mk_comptest( $self, @args );
            }
            else { $self->_mk_comptest }
        }

        # Fallback
        else {
            return 1 unless $self->_mk_compclass;
            $self->_mk_comptest;
        }
    }
    return 1;
}

=head3 mk_dir

Surprisingly, this function makes a directory.

=cut

sub mk_dir {
    my ( $self, $dir ) = @_;
    if ( -d $dir ) {
        print qq/ exists "$dir"\n/;
        return 0;
    }
    if ( mkpath $dir) {
        print qq/created "$dir"\n/;
        return 1;
    }
    die qq/Couldn't create "$dir", "$!"/;
}

=head3 mk_file

writes content to a file.

=cut

sub mk_file {
    my ( $self, $file, $content ) = @_;
    if ( -e $file ) {
        print qq/ exists "$file"\n/;
        return 0;
    }
    if ( my $f = IO::File->new("> $file") ) {
        print $f $content;
        print qq/created "$file"\n/;
        return 1;
    }
    die qq/Couldn't create "$file", "$!"/;
}

=head3 next_test

=cut

sub next_test {
    my ( $self, $tname ) = @_;
    if ($tname) { $tname = "$tname.t" }
    else {
        my $name   = $self->{name};
        my $prefix = $name;
        $prefix =~ s/::/_/g;
        $prefix         = lc $prefix;
        $tname          = $prefix . '.t';
        $self->{prefix} = $prefix;
    }
    my $dir  = $self->{test_dir};
    my $type = lc $self->{type};
    return File::Spec->catfile( $dir, $type, $tname );
}

=head3 render_file

Render and create a file from a template in DATA using 
Template Toolkit.

=cut

sub render_file {
    my ( $self, $file, $path, $vars ) = @_;
    $vars ||= {};
    my $t = Template->new;
    my $template = $self->get_file( ( caller(0) )[0], $file );
    return 0 unless $template;
    my $output;
    $t->process( \$template, { %{$self}, %$vars }, \$output );
    $self->mk_file( $path, $output );
}

sub _mk_dirs {
    my $self = shift;
    $self->mk_dir( $self->{dir} );
    $self->{script} = File::Spec->catdir( $self->{dir}, 'script' );
    $self->mk_dir( $self->{script} );
    $self->{lib} = File::Spec->catdir( $self->{dir}, 'lib' );
    $self->mk_dir( $self->{lib} );
    $self->{root} = File::Spec->catdir( $self->{dir}, 'root' );
    $self->mk_dir( $self->{root} );
    $self->{t} = File::Spec->catdir( $self->{dir}, 't' );
    $self->mk_dir( $self->{t} );
    $self->mk_dir( File::Spec->catdir( $self->{t}, 'm' ) );
    $self->mk_dir( File::Spec->catdir( $self->{t}, 'v' ) );
    $self->mk_dir( File::Spec->catdir( $self->{t}, 'c' ) );
    $self->{class} = File::Spec->catdir( split( /\:\:/, $self->{name} ) );
    $self->{mod} = File::Spec->catdir( $self->{lib}, $self->{class} );
    $self->mk_dir( $self->{mod} );
    $self->{m} = File::Spec->catdir( $self->{mod}, 'M' );
    $self->mk_dir( $self->{m} );
    $self->{v} = File::Spec->catdir( $self->{mod}, 'V' );
    $self->mk_dir( $self->{v} );
    $self->{c} = File::Spec->catdir( $self->{mod}, 'C' );
    $self->mk_dir( $self->{c} );
    $self->{base} = File::Spec->rel2abs( $self->{dir} );
}

sub _mk_appclass {
    my $self = shift;
    my $mod  = $self->{mod};
    $self->render_file( 'appclass', "$mod.pm" );
}

sub _mk_build {
    my $self = shift;
    my $dir  = $self->{dir};
    $self->render_file( 'build', "$dir\/Build.PL" );
}

sub _mk_makefile {
    my $self = shift;
    my $dir  = $self->{dir};
    $self->render_file( 'makefile', "$dir\/Makefile.PL" );
}

sub _mk_readme {
    my $self = shift;
    my $dir  = $self->{dir};
    $self->render_file( 'readme', "$dir\/README" );
}

sub _mk_changes {
    my $self = shift;
    my $dir  = $self->{dir};
    my $time = localtime time;
    $self->render_file( 'changes', "$dir\/Changes", { time => $time } );
}

sub _mk_apptest {
    my $self = shift;
    my $t    = $self->{t};
    $self->render_file( 'apptest',         "$t\/01app.t" );
    $self->render_file( 'podtest',         "$t\/02pod.t" );
    $self->render_file( 'podcoveragetest', "$t\/03podcoverage.t" );
}

sub _mk_cgi {
    my $self   = shift;
    my $script = $self->{script};
    my $appprefix = $self->{appprefix};
    $self->render_file( 'cgi', "$script\/$appprefix\_cgi.pl" );
    chmod 0700, "$script/$appprefix\_cgi.pl";
}

sub _mk_fcgi {
    my $self   = shift;
    my $script = $self->{script};
    my $appprefix = $self->{appprefix};
    $self->render_file( 'fcgi', "$script\/$appprefix\_fcgi.pl" );
    chmod 0700, "$script/$appprefix\_fcgi.pl";
}

sub _mk_server {
    my $self   = shift;
    my $script = $self->{script};
    my $appprefix = $self->{appprefix};
    $self->render_file( 'server', "$script\/$appprefix\_server.pl" );
    chmod 0700, "$script/$appprefix\_server.pl";
}

sub _mk_test {
    my $self   = shift;
    my $script = $self->{script};
    my $appprefix = $self->{appprefix};
    $self->render_file( 'test', "$script/$appprefix\_test.pl" );
    chmod 0700, "$script/$appprefix\_test.pl";
}

sub _mk_create {
    my $self   = shift;
    my $script = $self->{script};
    my $appprefix = $self->{appprefix};
    $self->render_file( 'create', "$script\/$appprefix\_create.pl" );
    chmod 0700, "$script/$appprefix\_create.pl";
}

sub _mk_compclass {
    my $self = shift;
    my $file = $self->{file};
    return $self->render_file( 'compclass', "$file" );
}

sub _mk_comptest {
    my $self = shift;
    my $test = $self->{test};
    $self->render_file( 'comptest', "$test" );
}

=head1 HELPERS

Helpers are classes that provide two methods.

    * mk_compclass - creates the Component class
    * mk_comptest  - creates the Component test

So when you call C<bin/create view MyView TT>, create would try to execute
Catalyst::Helper::View::TT->mk_compclass and
Catalyst::Helper::View::TT->mk_comptest.

See L<Catalyst::Helper::View::TT> and L<Catalyst::Helper::Model::CDBI> for
examples.

All helper classes should be under one of the following namespaces.

    Catalyst::Helper::Model::
    Catalyst::Helper::View::
    Catalyst::Helper::Controller::

=head1 NOTE

The helpers will read author name from /etc/passwd by default.
To override, please export the AUTHOR variable.

=head1 SEE ALSO

L<Catalyst::Manual>, L<Catalyst::Test>, L<Catalyst::Request>,
L<Catalyst::Response>, L<Catalyst>

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 LICENSE

This library is free software . You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut

1;
__DATA__

__appclass__
package [% name %];

use strict;
use Catalyst qw/-Debug/;

our $VERSION = '0.01';

[% name %]->config( name => '[% name %]' );

[% name %]->setup;

sub default : Private {
    my ( $self, $c ) = @_;
    $c->res->output('Congratulations, [% name %] is on Catalyst!');
}

=head1 NAME

[% name %] - A very nice application

=head1 SYNOPSIS

    Very simple to use

=head1 DESCRIPTION

Very nice application.

=head1 AUTHOR

[%author%]

=head1 LICENSE

This library is free software . You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut

1;

__makefile__
    unless ( eval "use Module::Build::Compat 0.02; 1" ) {
        print "This module requires Module::Build to install itself.\n";

        require ExtUtils::MakeMaker;
        my $yn =
          ExtUtils::MakeMaker::prompt( '  Install Module::Build now from CPAN?',            'y' );

        unless ( $yn =~ /^y/i ) {
            die " *** Cannot install without Module::Build.  Exiting ...\n";
        }

        require Cwd;
        require File::Spec;
        require CPAN;

        # Save this 'cause CPAN will chdir all over the place.
        my $cwd      = Cwd::cwd();
        my $makefile = File::Spec->rel2abs($0);

        CPAN::Shell->install('Module::Build::Compat')
          or die " *** Cannot install without Module::Build.  Exiting ...\n";

        chdir $cwd or die "Cannot chdir() back to $cwd: $!";
    }
    eval "use Module::Build::Compat 0.02; 1" or die $@;
    use lib '_build/lib';
    Module::Build::Compat->run_build_pl( args => \@ARGV );
    require Module::Build;
    Module::Build::Compat->write_makefile( build_class => 'Module::Build' );

__build__
use strict;
use Catalyst::Build;

my $build = Catalyst::Build->new(
    create_makefile_pl => 'passthrough',
    license            => 'perl',
    module_name        => '[% name %]',
    requires           => { Catalyst => '5.10' },
    create_makefile_pl => 'passthrough',
    script_files       => [ glob('script/*') ],
    test_files         => [ glob('t/*.t'), glob('t/*/*.t') ]
);
$build->create_build_script;

__readme__
Run script/[% apprefix %]_server.pl to test the application.

__changes__
This file documents the revision history for Perl extension [% name %].

0.01  [% time %]
        - initial revision, generated by Catalyst

__apptest__
use Test::More tests => 2;
use_ok( Catalyst::Test, '[% name %]' );

ok( request('/')->is_success );

__podtest__
use Test::More;

eval "use Test::Pod 1.14";
plan skip_all => 'Test::Pod 1.14 required' if $@;
plan skip_all => 'set TEST_POD to enable this test' unless $ENV{TEST_POD};

all_pod_files_ok();

__podcoveragetest__
use Test::More;

eval "use Test::Pod::Coverage 1.04";
plan skip_all => 'Test::Pod::Coverage 1.04 required' if $@;
plan skip_all => 'set TEST_POD to enable this test' unless $ENV{TEST_POD};

all_pod_coverage_ok();

__cgi__
[% startperl %] -w
BEGIN { $ENV{CATALYST_ENGINE} = 'CGI' }

use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use [% name %];

[% name %]->run;

1;

=head1 NAME

cgi - Catalyst CGI

=head1 SYNOPSIS

See L<Catalyst::Manual>

=head1 DESCRIPTION

Run a Catalyst application as cgi.

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software. You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut

__fcgi__
[% startperl %] -w

BEGIN { $ENV{CATALYST_ENGINE} = 'FCGI' }

use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use [% name %];

[% name %]->run;

1;

=head1 NAME

fcgi - Catalyst FCGI

=head1 SYNOPSIS

See L<Catalyst::Manual>

=head1 DESCRIPTION

Run a Catalyst application as fcgi.

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software. You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut

__server__
[% startperl %] -w

BEGIN { 
    $ENV{CATALYST_ENGINE} = 'HTTP';
    $ENV{CATALYST_SCRIPT_GEN} = [% scriptgen %];
}  

use strict;
use Getopt::Long;
use Pod::Usage;
use FindBin;
use lib "$FindBin::Bin/../lib";
use [% name %];

my $help = 0;
my $port = 3000;

GetOptions( 'help|?' => \$help, 'port=s' => \$port );

pod2usage(1) if $help;

[% name %]->run($port);

1;

=head1 NAME

server - Catalyst Testserver

=head1 SYNOPSIS

server.pl [options]

 Options:
   -? -help    display this help and exits
   -p -port    port (defaults to 3000)

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst Testserver for this application.

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software. You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut

__test__
[% startperl %] -w

BEGIN { $ENV{CATALYST_ENGINE} = 'Test' }

use strict;
use Getopt::Long;
use Pod::Usage;
use FindBin;
use lib "$FindBin::Bin/../lib";
use [% name %];

my $help = 0;

GetOptions( 'help|?' => \$help );

pod2usage(1) if ( $help || !$ARGV[0] );

print [% name %]->run($ARGV[0])->content . "\n";

1;

=head1 NAME

test - Catalyst Test

=head1 SYNOPSIS

test.pl [options] uri

 Options:
   -help    display this help and exits

 Examples:
   test.pl http://localhost/some_action
   test.pl /some_action

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst action from the comand line.

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software. You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut

__create__
[% startperl %] -w

use strict;
use Getopt::Long;
use Pod::Usage;
use Catalyst::Helper;

my $help = 0;

GetOptions( 'help|?' => \$help );

pod2usage(1) if ( $help || !$ARGV[0] );

my $helper = Catalyst::Helper->new;
pod2usage(1) unless $helper->mk_component( '[% name %]', @ARGV );

1;

=head1 NAME

create - Create a new Catalyst Component

=head1 SYNOPSIS

create.pl [options] model|view|controller name [helper] [options]

 Options:
   -help    display this help and exits

 Examples:
   create.pl controller My::Controller
   create.pl view My::View
   create.pl view MyView TT
   create.pl view TT TT
   create.pl model My::Model
   create.pl model SomeDB CDBI dbi:SQLite:/tmp/my.db
   create.pl model AnotherDB CDBI dbi:Pg:dbname=foo root 4321
   create.pl Ajax

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Create a new Catalyst Component.

=head1 AUTHOR

Sebastian Riedel, C<sri\@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software. You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut

__compclass__
package [% class %];

use strict;
use base 'Catalyst::Base';

[% IF type == 'C' %]
sub default : Private {
    my ( $self, $c ) = @_;
    $c->res->output('Congratulations, [% class %] is on Catalyst!');
}

[% END %]
=head1 NAME

[% class %] - A Component

=head1 SYNOPSIS

    Very simple to use

=head1 DESCRIPTION

Very nice component.

=head1 AUTHOR

[%author%]

=head1 LICENSE

This library is free software . You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut

1;

__comptest__
[% IF type == 'C' %]
use Test::More tests => 3;
use_ok( Catalyst::Test, '[% app %]' );
use_ok('[% class %]');

ok( request('[% prefix %]')->is_success );
[% ELSE %]
use Test::More tests => 1;
use_ok('[% class %]');
[% END %]
