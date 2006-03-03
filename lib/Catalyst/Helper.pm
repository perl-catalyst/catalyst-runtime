package Catalyst::Helper;

use strict;
use base 'Class::Accessor::Fast';
use Config;
use File::Spec;
use File::Path;
use IO::File;
use FindBin;
use Template;
use Catalyst::Utils;
use Catalyst::Exception;

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
    my @files = split /^__(.+)__\r?\n/m, $data;
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

    # Needs to be here for PAR
    require Catalyst;

    if ( $name =~ /[^\w\:]/ ) {
        warn "Error: Invalid application name.\n";
        return 0;
    }
    $self->{name} = $name;
    $self->{dir}  = $name;
    $self->{dir} =~ s/\:\:/-/g;
    $self->{script}    = File::Spec->catdir( $self->{dir}, 'script' );
    $self->{appprefix} = Catalyst::Utils::appprefix($name);
    $self->{startperl} = "#!$Config{perlpath} -w";
    $self->{scriptgen} = $Catalyst::CATALYST_SCRIPT_GEN || 4;
    $self->{author}    = $self->{author} = $ENV{'AUTHOR'}
      || eval { @{ [ getpwuid($<) ] }[6] }
      || 'Catalyst developer';

    my $gen_scripts  = ( $self->{makefile} ) ? 0 : 1;
    my $gen_makefile = ( $self->{scripts} )  ? 0 : 1;
    my $gen_app = ( $self->{scripts} || $self->{makefile} ) ? 0 : 1;

    if ($gen_app) {
        $self->_mk_dirs;
        $self->_mk_config;
        $self->_mk_appclass;
        $self->_mk_rootclass;
        $self->_mk_readme;
        $self->_mk_changes;
        $self->_mk_apptest;
        $self->_mk_images;
        $self->_mk_favicon;
    }
    if ($gen_makefile) {
        $self->_mk_makefile;
    }
    if ($gen_scripts) {
        $self->_mk_cgi;
        $self->_mk_fastcgi;
        $self->_mk_server;
        $self->_mk_test;
        $self->_mk_create;
    }
    return $self->{dir};
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
      || eval { @{ [ getpwuid($<) ] }[6] }
      || 'A clever guy';
    $self->{base} ||= File::Spec->catdir( $FindBin::Bin, '..' );
    unless ( $_[0] =~ /^(?:model|view|controller)$/i ) {
        my $helper = shift;
        my @args   = @_;
        my $class  = "Catalyst::Helper::$helper";
        eval "require $class";

        if ($@) {
            Catalyst::Exception->throw(
                message => qq/Couldn't load helper "$class", "$@"/ );
        }

        if ( $class->can('mk_stuff') ) {
            return 1 unless $class->mk_stuff( $self, @args );
        }
    }
    else {
        my $type   = shift;
        my $name   = shift || "Missing name for model/view/controller";
        my $helper = shift;
        my @args   = @_;
        return 0 if $name =~ /[^\w\:]/;
        $type              = lc $type;
        $self->{long_type} = ucfirst $type;
        $type              = 'M' if $type =~ /model/i;
        $type              = 'V' if $type =~ /view/i;
        $type              = 'C' if $type =~ /controller/i;
        my $appdir = File::Spec->catdir( split /\:\:/, $app );
        my $test_path =
          File::Spec->catdir( $FindBin::Bin, '..', 'lib', $appdir, 'C' );
        $type = $self->{long_type} unless -d $test_path;
        $self->{type}  = $type;
        $self->{name}  = $name;
        $self->{class} = "$app\::$type\::$name";

        # Class
        my $path =
          File::Spec->catdir( $FindBin::Bin, '..', 'lib', $appdir, $type );
        my $file = $name;
        if ( $name =~ /\:/ ) {
            my @path = split /\:\:/, $name;
            $file = pop @path;
            $path = File::Spec->catdir( $path, @path );
        }
        $self->mk_dir($path);
        $file = File::Spec->catfile( $path, "$file.pm" );
        $self->{file} = $file;

        # Test
        $self->{test_dir} = File::Spec->catdir( $FindBin::Bin, '..', 't' );
        $self->{test}     = $self->next_test;

        # Helper
        if ($helper) {
            my $comp  = $self->{long_type};
            my $class = "Catalyst::Helper::$comp\::$helper";
            eval "require $class";

            if ($@) {
                Catalyst::Exception->throw(
                    message => qq/Couldn't load helper "$class", "$@"/ );
            }

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
    if ( mkpath [$dir] ) {
        print qq/created "$dir"\n/;
        return 1;
    }

    Catalyst::Exception->throw( message => qq/Couldn't create "$dir", "$!"/ );
}

=head3 mk_file

writes content to a file.

=cut

sub mk_file {
    my ( $self, $file, $content ) = @_;
    if ( -e $file ) {
        print qq/ exists "$file"\n/;
        return 0
          unless ( $self->{'.newfiles'}
            || $self->{scripts}
            || $self->{makefile} );
        if ( $self->{'.newfiles'} ) {
            if ( my $f = IO::File->new("< $file") ) {
                my $oldcontent = join( '', (<$f>) );
                return 0 if $content eq $oldcontent;
            }
            $file .= '.new';
        }
    }
    if ( my $f = IO::File->new("> $file") ) {
        binmode $f;
        print $f $content;
        print qq/created "$file"\n/;
        return 1;
    }

    Catalyst::Exception->throw( message => qq/Couldn't create "$file", "$!"/ );
}

=head3 next_test

=cut

sub next_test {
    my ( $self, $tname ) = @_;
    if ($tname) { $tname = "$tname.t" }
    else {
        my $name   = $self->{name};
        my $prefix = $name;
        $prefix =~ s/::/-/g;
        $prefix         = $prefix;
        $tname          = $prefix . '.t';
        $self->{prefix} = $prefix;
        $prefix         = lc $prefix;
        $prefix =~ s/-/\//g;
        $self->{uri} = "/$prefix";
    }
    my $dir  = $self->{test_dir};
    my $type = lc $self->{type};
    $self->mk_dir($dir);
    return File::Spec->catfile( $dir, "$type\_$tname" );
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
    $t->process( \$template, { %{$self}, %$vars }, \$output )
      || Catalyst::Exception->throw(
        message => qq/Couldn't process "$file", / . $t->error() );
    $self->mk_file( $path, $output );
}

sub _mk_dirs {
    my $self = shift;
    $self->mk_dir( $self->{dir} );
    $self->mk_dir( $self->{script} );
    $self->{lib} = File::Spec->catdir( $self->{dir}, 'lib' );
    $self->mk_dir( $self->{lib} );
    $self->{root} = File::Spec->catdir( $self->{dir}, 'root' );
    $self->mk_dir( $self->{root} );
    $self->{static} = File::Spec->catdir( $self->{root}, 'static' );
    $self->mk_dir( $self->{static} );
    $self->{images} = File::Spec->catdir( $self->{static}, 'images' );
    $self->mk_dir( $self->{images} );
    $self->{t} = File::Spec->catdir( $self->{dir}, 't' );
    $self->mk_dir( $self->{t} );

    $self->{class} = File::Spec->catdir( split( /\:\:/, $self->{name} ) );
    $self->{mod} = File::Spec->catdir( $self->{lib}, $self->{class} );
    $self->mk_dir( $self->{mod} );

    if ( $self->{short} ) {
        $self->{m} = File::Spec->catdir( $self->{mod}, 'M' );
        $self->mk_dir( $self->{m} );
        $self->{v} = File::Spec->catdir( $self->{mod}, 'V' );
        $self->mk_dir( $self->{v} );
        $self->{c} = File::Spec->catdir( $self->{mod}, 'C' );
        $self->mk_dir( $self->{c} );
    }
    else {
        $self->{m} = File::Spec->catdir( $self->{mod}, 'Model' );
        $self->mk_dir( $self->{m} );
        $self->{v} = File::Spec->catdir( $self->{mod}, 'View' );
        $self->mk_dir( $self->{v} );
        $self->{c} = File::Spec->catdir( $self->{mod}, 'Controller' );
        $self->mk_dir( $self->{c} );
    }
    my $name = $self->{name};
    $self->{rootname} =
      $self->{short} ? "$name\::C::Root" : "$name\::Controller::Root";
    $self->{base} = File::Spec->rel2abs( $self->{dir} );
}

sub _mk_appclass {
    my $self = shift;
    my $mod  = $self->{mod};
    $self->render_file( 'appclass', "$mod.pm" );
}

sub _mk_rootclass {
    my $self = shift;
    $self->render_file( 'rootclass',
        File::Spec->catfile( $self->{c}, "Root.pm" ) );
}

sub _mk_makefile {
    my $self = shift;
    $self->{path} = File::Spec->catfile( 'lib', split( '::', $self->{name} ) );
    $self->{path} .= '.pm';
    my $dir = $self->{dir};
    $self->render_file( 'makefile', "$dir\/Makefile.PL" );

    if ( $self->{makefile} ) {

        # deprecate the old Build.PL file when regenerating Makefile.PL
        $self->_deprecate_file(
            File::Spec->catdir( $self->{dir}, 'Build.PL' ) );
    }
}

sub _mk_config {
    my $self      = shift;
    my $dir       = $self->{dir};
    my $appprefix = $self->{appprefix};
    $self->render_file( 'config',
        File::Spec->catfile( $dir, "$appprefix.yml" ) );
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
    my $self      = shift;
    my $script    = $self->{script};
    my $appprefix = $self->{appprefix};
    $self->render_file( 'cgi', "$script\/$appprefix\_cgi.pl" );
    chmod 0700, "$script/$appprefix\_cgi.pl";
}

sub _mk_fastcgi {
    my $self      = shift;
    my $script    = $self->{script};
    my $appprefix = $self->{appprefix};
    $self->render_file( 'fastcgi', "$script\/$appprefix\_fastcgi.pl" );
    chmod 0700, "$script/$appprefix\_fastcgi.pl";
}

sub _mk_server {
    my $self      = shift;
    my $script    = $self->{script};
    my $appprefix = $self->{appprefix};
    $self->render_file( 'server', "$script\/$appprefix\_server.pl" );
    chmod 0700, "$script/$appprefix\_server.pl";
}

sub _mk_test {
    my $self      = shift;
    my $script    = $self->{script};
    my $appprefix = $self->{appprefix};
    $self->render_file( 'test', "$script/$appprefix\_test.pl" );
    chmod 0700, "$script/$appprefix\_test.pl";
}

sub _mk_create {
    my $self      = shift;
    my $script    = $self->{script};
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

sub _mk_images {
    my $self   = shift;
    my $images = $self->{images};
    my @images =
      qw/catalyst_logo btn_120x50_built btn_120x50_built_shadow
      btn_120x50_powered btn_120x50_powered_shadow btn_88x31_built
      btn_88x31_built_shadow btn_88x31_powered btn_88x31_powered_shadow/;
    for my $name (@images) {
        my $hex = $self->get_file( ( caller(0) )[0], $name );
        my $image = pack "H*", $hex;
        $self->mk_file( File::Spec->catfile( $images, "$name.png" ), $image );
    }
}

sub _mk_favicon {
    my $self    = shift;
    my $root    = $self->{root};
    my $hex     = $self->get_file( ( caller(0) )[0], 'favicon' );
    my $favicon = pack "H*", $hex;
    $self->mk_file( File::Spec->catfile( $root, "favicon.ico" ), $favicon );

}

sub _deprecate_file {
    my ( $self, $file ) = @_;
    if ( -e $file ) {
        my $oldcontent;
        if ( my $f = IO::File->new("< $file") ) {
            $oldcontent = join( '', (<$f>) );
        }
        my $newfile = $file . '.deprecated';
        if ( my $f = IO::File->new("> $newfile") ) {
            binmode $f;
            print $f $oldcontent;
            print qq/created "$newfile"\n/;
            unlink $file;
            print qq/removed "$file"\n/;
            return 1;
        }
        Catalyst::Exception->throw(
            message => qq/Couldn't create "$file", "$!"/ );
    }
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

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
__DATA__

__appclass__
package [% name %];

use strict;
use warnings;

#
# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
# Static::Simple: will serve static files from the application's root 
# directory
#
use Catalyst qw/-Debug ConfigLoader Static::Simple/;

our $VERSION = '0.01';

#
# Start the application
#
__PACKAGE__->setup;

#
# IMPORTANT: Please look into [% rootname %] for more
#

=head1 NAME

[% name %] - Catalyst based application

=head1 SYNOPSIS

    script/[% appprefix %]_server.pl

=head1 DESCRIPTION

Catalyst based application.

=head1 SEE ALSO

L<[% rootname %]>, L<Catalyst>

=head1 AUTHOR

[% author %]

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
__rootclass__
package [% rootname %];

use strict;
use warnings;
use base 'Catalyst::Controller';

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

[% rootname %] - Root Controller for this Catalyst based application

=head1 SYNOPSIS

See L<[% name %]>.

=head1 DESCRIPTION

Root Controller for this Catalyst based application.

=head1 METHODS

=cut

=head2 default

=cut

#
# Output a friendly welcome message
#
sub default : Private {
    my ( $self, $c ) = @_;

    # Hello World
    $c->response->body( $c->welcome_message );
}

#
# Uncomment and modify this end action after adding a View component
#
#=head2 end
#
#=cut
#
#sub end : Private {
#    my ( $self, $c ) = @_;
#
#    # Forward to View unless response body is already defined
#    $c->forward( $c->view('') ) unless $c->response->body;
#}

=head1 AUTHOR

[% author %]

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
__makefile__
use inc::Module::Install;

name '[% dir %]';
all_from '[% path %]';

requires Catalyst => '5.64';

catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
__config__
---
name: [% name %]
__readme__
Run script/[% appprefix %]_server.pl to test the application.
__changes__
This file documents the revision history for Perl extension [% name %].

0.01  [% time %]
        - initial revision, generated by Catalyst
__apptest__
use strict;
use warnings;
use Test::More tests => 2;

BEGIN { use_ok 'Catalyst::Test', '[% name %]' }

ok( request('/')->is_success, 'Request should succeed' );
__podtest__
use strict;
use warnings;
use Test::More;

eval "use Test::Pod 1.14";
plan skip_all => 'Test::Pod 1.14 required' if $@;
plan skip_all => 'set TEST_POD to enable this test' unless $ENV{TEST_POD};

all_pod_files_ok();
__podcoveragetest__
use strict;
use warnings;
use Test::More;

eval "use Test::Pod::Coverage 1.04";
plan skip_all => 'Test::Pod::Coverage 1.04 required' if $@;
plan skip_all => 'set TEST_POD to enable this test' unless $ENV{TEST_POD};

all_pod_coverage_ok();
__cgi__
[% startperl %]

BEGIN { $ENV{CATALYST_ENGINE} ||= 'CGI' }

use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use [% name %];

[% name %]->run;

1;

=head1 NAME

[% appprefix %]_cgi.pl - Catalyst CGI

=head1 SYNOPSIS

See L<Catalyst::Manual>

=head1 DESCRIPTION

Run a Catalyst application as cgi.

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
__fastcgi__
[% startperl %]

BEGIN { $ENV{CATALYST_ENGINE} ||= 'FastCGI' }

use strict;
use Getopt::Long;
use Pod::Usage;
use FindBin;
use lib "$FindBin::Bin/../lib";
use [% name %];

my $help = 0;
my ( $listen, $nproc, $pidfile, $manager, $detach );
 
GetOptions(
    'help|?'      => \$help,
    'listen|l=s'  => \$listen,
    'nproc|n=i'   => \$nproc,
    'pidfile|p=s' => \$pidfile,
    'manager|M=s' => \$manager,
    'daemon|d'    => \$detach,
);

pod2usage(1) if $help;

[% name %]->run( 
    $listen, 
    {   nproc   => $nproc,
        pidfile => $pidfile, 
        manager => $manager,
        detach  => $detach,
    }
);

1;

=head1 NAME

[% appprefix %]_fastcgi.pl - Catalyst FastCGI

=head1 SYNOPSIS

[% appprefix %]_fastcgi.pl [options]
 
 Options:
   -? -help      display this help and exits
   -l -listen    Socket path to listen on
                 (defaults to standard input)
                 can be HOST:PORT, :PORT or a
                 filesystem path
   -n -nproc     specify number of processes to keep
                 to serve requests (defaults to 1,
                 requires -listen)
   -p -pidfile   specify filename for pid file
                 (requires -listen)
   -d -daemon    daemonize (requires -listen)
   -M -manager   specify alternate process manager
                 (FCGI::ProcManager sub-class)
                 or empty string to disable

=head1 DESCRIPTION

Run a Catalyst application as fastcgi.

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
__server__
[% startperl %]

BEGIN { 
    $ENV{CATALYST_ENGINE} ||= 'HTTP';
    $ENV{CATALYST_SCRIPT_GEN} = [% scriptgen %];
}  

use strict;
use Getopt::Long;
use Pod::Usage;
use FindBin;
use lib "$FindBin::Bin/../lib";

my $debug         = 0;
my $fork          = 0;
my $help          = 0;
my $host          = undef;
my $port          = 3000;
my $keepalive     = 0;
my $restart       = 0;
my $restart_delay = 1;
my $restart_regex = '\.yml$|\.yaml$|\.pm$';

my @argv = @ARGV;

GetOptions(
    'debug|d'           => \$debug,
    'fork'              => \$fork,
    'help|?'            => \$help,
    'host=s'            => \$host,
    'port=s'            => \$port,
    'keepalive|k'       => \$keepalive,
    'restart|r'         => \$restart,
    'restartdelay|rd=s' => \$restart_delay,
    'restartregex|rr=s' => \$restart_regex
);

pod2usage(1) if $help;

if ( $restart ) {
    $ENV{CATALYST_ENGINE} = 'HTTP::Restarter';
}
if ( $debug ) {
    $ENV{CATALYST_DEBUG} = 1;
}

# This is require instead of use so that the above environment
# variables can be set at runtime.
require [% name %];

[% name %]->run( $port, $host, {
    argv          => \@argv,
    'fork'        => $fork,
    keepalive     => $keepalive,
    restart       => $restart,
    restart_delay => $restart_delay,
    restart_regex => qr/$restart_regex/
} );

1;

=head1 NAME

[% appprefix %]_server.pl - Catalyst Testserver

=head1 SYNOPSIS

[% appprefix %]_server.pl [options]

 Options:
   -d -debug          force debug mode
   -f -fork           handle each request in a new process
                      (defaults to false)
   -? -help           display this help and exits
      -host           host (defaults to all)
   -p -port           port (defaults to 3000)
   -k -keepalive      enable keep-alive connections
   -r -restart        restart when files got modified
                      (defaults to false)
   -rd -restartdelay  delay between file checks
   -rr -restartregex  regex match files that trigger
                      a restart when modified
                      (defaults to '\.yml$|\.yaml$|\.pm$')

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst Testserver for this application.

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
__test__
[% startperl %]

use strict;
use Getopt::Long;
use Pod::Usage;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Catalyst::Test '[% name %]';

my $help = 0;

GetOptions( 'help|?' => \$help );

pod2usage(1) if ( $help || !$ARGV[0] );

print request($ARGV[0])->content . "\n";

1;

=head1 NAME

[% appprefix %]_test.pl - Catalyst Test

=head1 SYNOPSIS

[% appprefix %]_test.pl [options] uri

 Options:
   -help    display this help and exits

 Examples:
   [% appprefix %]_test.pl http://localhost/some_action
   [% appprefix %]_test.pl /some_action

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst action from the command line.

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
__create__
[% startperl %]

use strict;
use Getopt::Long;
use Pod::Usage;
use Catalyst::Helper;

my $force = 0;
my $mech  = 0;
my $help  = 0;

GetOptions(
    'nonew|force'    => \$force,
    'mech|mechanize' => \$mech,
    'help|?'         => \$help
 );

pod2usage(1) if ( $help || !$ARGV[0] );

my $helper = Catalyst::Helper->new( { '.newfiles' => !$force, mech => $mech } );

pod2usage(1) unless $helper->mk_component( '[% name %]', @ARGV );

1;

=head1 NAME

[% appprefix %]_create.pl - Create a new Catalyst Component

=head1 SYNOPSIS

[% appprefix %]_create.pl [options] model|view|controller name [helper] [options]

 Options:
   -force        don't create a .new file where a file to be created exists
   -mechanize    use Test::WWW::Mechanize::Catalyst for tests if available
   -help         display this help and exits

 Examples:
   [% appprefix %]_create.pl controller My::Controller
   [% appprefix %]_create.pl -mechanize controller My::Controller
   [% appprefix %]_create.pl view My::View
   [% appprefix %]_create.pl view MyView TT
   [% appprefix %]_create.pl view TT TT
   [% appprefix %]_create.pl model My::Model
   [% appprefix %]_create.pl model SomeDB CDBI dbi:SQLite:/tmp/my.db
   [% appprefix %]_create.pl model AnotherDB CDBI dbi:Pg:dbname=foo root 4321

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Create a new Catalyst Component.

Existing component files are not overwritten.  If any of the component files
to be created already exist the file will be written with a '.new' suffix.
This behavior can be suppressed with the C<-force> option.

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
__compclass__
package [% class %];

use strict;
use warnings;
use base 'Catalyst::[% long_type %]';

=head1 NAME

[% class %] - Catalyst [% long_type %]

=head1 SYNOPSIS

See L<[% app %]>

=head1 DESCRIPTION

Catalyst [% long_type %].
[% IF long_type == 'Controller' %]
=head1 METHODS

=cut

#
# Uncomment and modify this or add new actions to fit your needs
#
#=head2 default
#
#=cut
#
#sub default : Private {
#    my ( $self, $c ) = @_;
#
#    # Hello World
#    $c->response->body('[% class %] is on Catalyst!');
#}

[% END %]
=head1 AUTHOR

[%author%]

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
__comptest__
use strict;
use warnings;
[% IF long_type == 'Controller' %][% IF mech %]use Test::More;

eval "use Test::WWW::Mechanize::Catalyst '[% app %]'";
plan $@
    ? ( skip_all => 'Test::WWW::Mechanize::Catalyst required' )
    : ( tests => 2 );

ok( my $mech = Test::WWW::Mechanize::Catalyst->new, 'Created mech object' );

$mech->get_ok( 'http://localhost[% uri %]' );
[% ELSE %]use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', '[% app %]' }
BEGIN { use_ok '[% class %]' }

ok( request('[% uri %]')->is_success, 'Request should succeed' );
[% END %]
[% ELSE %]use Test::More tests => 1;

BEGIN { use_ok '[% class %]' }
[% END %]
__btn_120x50_built__
89504e470d0a1a0a0000000d4948445200000078000000320803000000a079efea0000000467414d410000d6d8d44f58320000001974455874536f6674776172650041646f626520496d616765526561647971c9653c00000300504c5445d1d3cf8b8a89f4f4f3a4a29dd5d5d3dadad5b38d8bfe0000ef9493dededca1a1a0cb302fdfe0dee4e4e2717170cc8c8cfbfbfbda0101f9f9f975716cc9c3bfc9a6a6cecfcefc3837f945443e3e3ee6e7e6b65756eaeae8d3cccbe9e6e4aeafadcdcecb9d9c99eaa9a8e1e2e0fcf4f3fe1919c9cbc7bc7c7bd7d9d5ffffffcb9393f4f4f4dd5655f1ebe8e4b8b6d9dad8969695e95b5ad3d3d3fbfdfa575757b2b2b2d76665d37575eb7877e2e4e2e40000bbb9b5e2e3e2d5d7d3d58584ecedeba9a9a9d2bab8ccb3b2cac6c5fbfbf9827d78606060f1f1f0c5c5c5e4e5e3bebebbeaece9e43c3cf5d7d7e8e8e6cacac9caafae534c46dedfdcb1b1b0ce7d7cc1c1c07d7e7df1f3eeb9bab8d8d8d7c89d9cf55756e6e8e6f46b6b9a9997676767b4b5b4fd2827cebdbcd8d6d3d5acaabbacab3a322aca5756e3cdcc4e4e4ee0e0e0635d57f20000ec6969aba9a6f47777d2d3d1eeeeeedbdedbcfd0ccdadcd9d0c4c2be6664d94342edcdccadada9434343eddcdc87827dc4c4c2e0ddddf3f3f1e4e6e2dedbdafdfbfae94646dddedbe1e1de92918eeeeeec67625c6a6a6a443d36bcbcbcdededaebd5d4ebeaeadadada7c7874cfcacac49493ececece5d6d5b5b4b1e5c4c3eef1eccd6260b9b7b4908d8ad0d2d0ecc6c5fdfdfb2e261e4f4942d3d2cfbe3a39f2f2f1c2b3b0d81b1bf60a0ad1d1cffe0f0eafb0afccb8b7aeaeadf7f7f7cbccc9dbdcda5a544ec7c8c4737373e6e6e4bbbbbab7b8b6afafad6f6b65acacabb2b5b2ca4e4db3b2afa6a6a3c4c3bf79756fc2c4c1e4e6e4726e67d9dcd8d7d7d6989691e2e0dff5c4c46d67614d47409e9f9d221911dadbd8dadbd9dbdbd9dbdbd8f9f9f7f1f3f1dadad8dcdcdafffffddcdcdbdcdcd9dcdddbfdfffddddddbf7f9f7dadad9fdfdfdf4f7f3f3f1f0eceeecfffdfddbdad8473f39fdfffff9faf9fffdffdcdddadddddaf7f7f9fdfdffbdbbb9f9f7f7b1b2b1f7f4f2e6e5e4ebe3e2e38483e0dcdbdbdad9d36f6ef7e1e0e59898f31818e52b2bf2f4f2d1c9c8d5100fdac6c2dddcdbf7f9f9eceeeed6d1cfe7c8c6b77271ffffff648c2af90000010074524e53ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0053f7072500000a6b4944415478daec586b545357164e68a84d9a041a6b780818a162425a2e0a11814428a258c04041141011ada50a7d400255510a2a216d51caf42d547c4c052d51283a9d8aa52d75941b42b884b7a8287ddaaa9dd63e9c35e3d4d9fb2448e8c3ceac65f935dfbd679fbdbffd9df3dd47c2ca8275e377509ccc7eae4d7ce3b683f53b7d76e173ec80a50bddda26d6b8d64d9871d4c059c4cb58c79e50e3a5556dc90507230f3e93323da86c028d0356b6cd4ff0545edaa28e6e99ee363271c6856d61534e6c894c28a8c8cbdbd8183161c67985bcd59ec37e80c897c2aba707d5ff21c66cb75f626166e4330968ec375c71a9cdedf6a130e0a6319bddd67c741a1c0888d3a6615194f0f514273f2727a7eb6a8f246bc7aa40c1581c23adcc349bd48e1ead49ca6b5e983c6a5cc84b76ff15445e5f0db64e7ed9eeb713caa466e1a8f1ba66c1430497acd3436f93ccf341651af87a12aac4a678ff213b94e0f97ec9d8da4ba3ba9bb8342ec37e6ec4ca9bc61b7d9402a54010a204080410429418f9ad4eabaf6f2104f036d29adbb810a20f51468f8c8c44479373844c5002195d2c1fab49372444c0b137cef6f9554c49f3f9ef30d2d8d81831d23802271ead50165540c20b207511d4ada40bda3d76c66f71f9bf808ecfbfbea4e08435fb79e7e7100945d1c211a108e646187922e1481e5f5e6568141605586b113947405b6b677cf410979b9808c37a127013f9694efd895c6b6ee3a09d489480d2d2512d972b120a8549d6ddf148c491189ed4b65418d0043997b400c072b576c6070635fd9f946afafb7b7bfbe1e8ed2ded85fcc7e0d550699023642fa4c07ffae9a7d02f252da04bfb01b031071dddadc67801a51a0147d8dc267487fc93d13b16818ff89d31e3a4d6aeaeeeeeae6e88873049bd7e3db5fbd08bf34c9003b0d3dddd6d0b5d5621aeb0cd5ddd783b29e1078442031a0bd19cb09ce4ca7acc6f1a7775992476c60a4e4f574f57574f4f4f7e7ecf2309f857c369b5e79c831f428de82107cc30f574c14ca43d563dd2e17093e17c88e1e122928bc27b900d8fadaf80981f4e1a84650c76c6999cf676a3b17db01d10b9c4efe08f050505a97e4b4c581b4ded83a66123f44c46ac4ded0c0c1326d6811a1883ed7fc7d9145f548453bb6970704c6182b570a0416abc9df1b1a67889369723ed3075a4051714f805cf9913ec34e7a0e71463474787c9d861840606134c108c183b6c1c618d3850dcd1515659898b3ada4907ae1bb528b7a9a5f6c67fcd6c69296a69b973eace9953ef9d19b77efdfd083fcfe034ea438a62c8990f9161605014090c959fcf60378cb24af21966906286d993270f5a651f5283d81ac412158b2448d8ddb17a5de6910644d8d4bbaf3dbaf71e826b6fbef9e6d3f7be9ba092a65246c688976b040c33641a05c3649c3c6965300ec3d87cf264bb71bc6a1836a09ecc397c2c770f4bebdb346afc42c6ba23290683afc16068d83b75aad5f79e500c3fddb917698341a2d56a6b59acdc5c8ee1581147da2ad5eedc194fa532cc0b0b72724cf987e07d7cf1c571b837235579f830f4a51c008bc3aaaeadd536371f37487c27d3741bb8f8361c798b18bfc00e2ae3a5946b2562ad569cb6f7d16ba1a1a1f7d846e8b53fdf9d269668c5d8134bc462f14759344de748763e0f137daa4522a609b492c33865bd03a253342dd142ff23b13807a2f63dec2c401a708744ec9b428c7985d39b529a627cf7c05360553ffdf4ccd07198f9d3cc6a6c419395cbaac54d4e3d5fb5a789ceda0d7befce65598df75467d5ecde4dd3350db92c9872595534fd97daea2cba06b3ac53351948a3712d4bd284c68a754776c624c74b542a1547c5e14c39f8eee363087d3cf4dd3d7f8206343918636093187c869c662861ab18150722e49c661895345d456895cab786cee280fc59ecfbaa54f12a15749bd1441b73148c1766fe34551cf962a494621c1d194769fedd8f8fc37a472923858f909191328cb48ca6cba4a0621c8f7f401ef6930c031b3b1a1d1db59bc92d551a9100edb334fd0ac8a71b21c9aa3c0e6bc0f849a994a272930fac64250b1ffd3ee19bfd93f6bfdeabd13cf260da92c7f64f1a87f59f68b6c3a1d16cdf0e71014d6fec86927b07783c0faf7b23773bf86ce16e2faa81fde15a166cd100a1d1708fd034fb593a4b73a81aafb0a66d3b596c829d5468bc9437f3b135c4e1f5fbbfff6e7fdd7771df8f379ea3cbe667eb743e7c1d820d1f165db68fce075e5e830e763acacf7e98a6753afe49787dbaa360cce703c1f7d1659fa71fcea227eb4e64f33f02e6fc0922f7f1e19f186e01e3a094c79cbeb15ac4cd99b7e61f5f97ac196fbce67d81a0047e9a840810f88e0d02c861274108ec77ac44805180511a025b2f1094400ad2920c7cf231b0a695744b04a40b8dd2a224306e7a7dde3ce2109cae4e4f4f77f7f28ab3f78d4b07fa6deca47ba57b79a9e1c6e887cf6f76c77bc02fd62be9ea2a3450c3ae59e7f16ba34e875ebada4bdd810fdf4bed9e030be01ba85627d3d605fc06306e8c7831eee519e03063ed2c7f8f8ad88ad8d8b57576c675f3c22b2e5f7d3bd6c3a3025a15b11e9b613bfabdd8e3e09ab5193e2db11e896044c7f643aca9c2560564a08d8d858b9c1eeb8125f81e821df0bbb8d3a32224fecb95ac034be7c75d593bcb65d6da2bae97f567f57abdd7abfeab466d57f95f9934ebf2d96dae2fbfa6479ccd83d010a6834c1f363f4f4f16e8f51c64f2e687bd96a73f0bc27fe9f528c7cf810e17f0c3a04f94ba308efeb5bcf478057c9ddc92235d66f9bfeaff84cb8ee8ce65c59dd1975de6ee988bcf60d28c2736ed3be35db7eadf3fcc5de5bf69c7039dc5673a9775228aa3e128264534a98bf1245876e60c14cbce14df01cfa4ec874ea0978108a6685842967b18d0b86d61fcfce06ddb5caf3ce03024070cc9372d77f5dee07ff5aaff1b9b8686e4433b5ceaaeeef35ee5eaea3af7b2dc0144430e30c91de45840896108d2af602d56d077805d86e0957c800a54db20ffca011dc22599f827b32c28b3b6d653d52932d79bcda2cf06207abbba2e9ffbd47297b9ce030366d1572b26ada87f60c3860d2bde309bcd030317ebcd174522b3f9e2c5cf6009d4900e98ff691e802ee42248a036e7d4b0516ebe583f801de00688646020af9618df50b82d7da7bc56e51ce51c1818e8ececbccb39306ab1f75d77792f4622102aef3ad7a766d42dff36702b14bb029da3a20277817a6b1476e15047edfb21500d4b5b8188dad7cad90a79a233c2a68872de15056460ab33a4cb6cc6376e2435aecb4db59c3bdd77bacfd2d767396db15864905a2ec820fbfcf469cb62f2ce5dee935d00d6f2f1694bdf39d07ede2723ea3e716ab9422a06e6cb3e99ec63693945b6b140eb82e563325b2c7d172c9673e7be841dfb1c7233c77e08cc4e95dd0a2ee443feb7dfe8ca15e50a85ac5c4129ca79721955aea4784a45b92c20421121067691922753882378f56c4a215e04f2d999633f7d6e6dbc75d52d8d65c498ad58a490511431a694e5608607b072854221c6169401b2ffc958f694ed51ff9631057752ae7849a18890136f4aacb019032be3c903648b2222b07c29e2e7c69c5b1adfb7a2aece75b1ecf660df38e3d9f25babbfbd5db63299fbeccce7468d838a664f2432ca468d2382788a09435240a1f2e67f7de22b174e1ccab27ff79fa87f18fe6f3c61f88f000300c6b973fc89c1298b0000000049454e44ae426082
__btn_120x50_built_shadow__
89504e470d0a1a0a0000000d4948445200000078000000320803000000a079efea0000000467414d410000d6d8d44f58320000001974455874536f6674776172650041646f626520496d616765526561647971c9653c00000300504c5445ba7472b2b2b28b8a89e3e4e2aeafadd1d3cfdadcd9f4f4f3a4a29dd4d5d3717271515151dadad5a1a1a0b38d8bfe0000ef9493fbfbfbcb302fdfe0decc8c8cda0101e6e7e675716cc9c3bfcdcfcdc9a6a6fc3837f945443e3e3eb65756d3cccbe9e6e4dedfdccdcecbeaa9a89d9c99e1e2e0f4f4f4f6f6f6fcf4f3fe1919d5d6d3c9cbc7d7d9d5cb9393dd5655f1ebe8e4b8b6d9dad8e95b5ad3d3d3e9e9e9626262fbfdfacfcfcfe2e3e2d76665d37575eb7877e2e4e2e40000f1f1f0bbb9b5d58584ecedeba9a9a9d2bab8ccb3b2cac6c5c2c1c07d7d7dfbfbf9827d78c5c5c5cacac8e4e5e3bfbdbbeaece9e43c3cf5d7d7e8e8e5caafae534c46dedfddb1b1af969695c87e7dd8d8d7f1f3eebebebeb9bab8c89d9cf55756e6e8e6f46b6b9a9997fd2827cebdbcd8d6d3d5acaab5b5b4bbacab3a322aca5756e0e0e0fcfcfce3cdcceaeaea4e4e4e645f59f20000ec6969aba9a6f47777eeeeeed2d3d1cfd0ccdededed0c4c2d94342edcdccacacaa434343eddcdceaeae887827dc4c4c2e0ddddf3f3f1dedbdafdfbfae94646dbdedbe1e1de94918c6c6c6ceeeeec67625cececec443d36dededadadada5b5b5bdddedcebd5d4eceae97c7874f2f2f2cfcacac49493e5d6d5b6b4b1e5c4c3eef1ecc86261b9b7b48f8d8bd1d1d1eac6c5fdfdfb2e261e4f4942d3d2cfbe3a39c2b3b0d81b1bf60a0afe0f0eccb8b7cbccc959534cc7c8c4e6e6e4bbbbbab7b8b6afafad6f6b65b3b4b2ca4e4da6a6a3c4c3bf787571c2c4c1e4e6e3726e67d7d7d6989691e2e0dfddddddf5c4c46d67614d47409e9f9dffffff221911f8f8f8f9f9f9dadbd8dadbd9dbdbd9dbdbd8f9f9f7f1f3f1dadad8dcdcdafffffddcdcd9dcdcdbdcdddbdddddbfdfffdf7f9f7fefefedadad9f9f9f8bcbcbcf8f9f8f4f7f3f3f1f0eceeecfffdfddbdad8473f39fdfffff9faf9fffdffdcdddadddddaf9f7f7f7f7f7bdbbb9fdfdfdf2f4f2fffefef7f4f2e6e5e4f7f9f9e0dcdbdbdad9585654605a54c0c0c0d36f6ee52b2bd6d1cfe38483f31818d1c9c8f7e1e0ebe3e2bebebbe59898eceeeed5100fdac6c21b4f2bb900000ae64944415478dabc587d5c93e51ade8783b658b646f89b80c090996314af081b88430815c10342829888681a91401f305110098d191135835f9d5296a8277111720c85c88eb2d78d31b7817c8b8aae92f0e429a3b4528fe7dcf7bb21d0879d3f3c5ccffbdecf7d5ff7f53cd7fbb1f973d0b47f82e211c66b2dd261edfd06eddeed1e46c16b8ca4c581ee2d936b2c75e7a4d56bc4d1dcb42cc6a41a2fae6a19c93b1479e8955533dfaa9a44e3b4c09685091eb2abdbe3e58d33ddad93675cd01236fdf8f6c884bccc9c9cfc6311ff27e39ea15f23a780bbce63d00f105916ae9e796de8be619c7131c3fdb7083c12f94a021afb0dbe7db5c5fdfea120e9ae3183d1d2503f050602e294295814257c3bddd9cfd9d9f9fadcb989b68e4d8182b13846da982976e9387ab4a6526e43e088dd7856017791cbef20f2fa3ab075f6cb70b99f902536bc663776c96a602ea570d5362dfd98ca3c9e94a580af074535d915f679e928d9b4b4a9696cedd5a513fae3b6b465d8cf8d08b41bcbb2f27d644c1993192a03309910426518f9cdceebae6fa708e0eda42db773a1943e5426b75aad72397558a9094a20e5c5a2b19aea868632d9a3c63d3e59f9193ebf8be9293eff1b781c0e27228a638de2e0b036435994c9e358b9493c0e4cd1503773ac908176ff5d637ed61415ff3750f2f9d717ac3b6ecb7eddf935741c9d9c63e5e860c691a3e35873f8a22a0df827d96a1d7558f9fce5eabbc69bb2eacdaa4d5ecb37a9bc6c0760b9176429ce9d5e9bb0522181b30a52d572d0a8549bb0a0b450eae0961275778dbdf0f40a4f6c59cc49aa835c45b5003aafe52ae938e344a2a4f34b554967e799339d30ce9c519d81fce790755097204791672005feabafbe82beaa135b40ab3a017d9c3e3638f6b9d88cf10254254c36a7a185e302f99794711f44f011e48f336e369b3b3acc1d66eae830275fbf9edcd1f1ce0203e46624617474d883794c689fcd1da7e06e56e5d473389a531ccc4f71fa2896bda862e8144707599fed309b0dc271c647c4ede676b3b9bdbdddc1a1fd9904fc57c3799d47f02107a811edd48019a67633cc94b4dda6473afcecd9b3e1fcf0beb3e1e17d90f7418426c4d8a1ccf0b3e10e70da8ef6769366bc31bbb555af6fed6d6d6dfd2e7285dfa19ff3f2f292fd5618a06ed51b5a7b0d837ae819f4581b5a4d701a30b19da881b3b7f53b9c0d31454538b51a7a7bc71406580b030d8898f1c675314245ae58d266684b09c9cbf30b090e0e710e7ed263babeadadcda06fd34303830126087a8c6d768e62f578a2b8ad6d6745052e6a6ba53a70dda845b95d2d9960bca1b1b1a8b1f1a1195fd36634ae88dbbcf971849f47480ae1401026eac0c464829320a860221c1c4c488611368983c9d44b980619d3a6f5da640e442fb67ab14445b41089e4f1c61b0ed722c2663c72e7d9038f52b8f3e1871fee2efa24412c4926f4263d5eae1e3068a2a651984c69274ed8188c83706e3b71a2553f5135081b102f657f44cfddcf52f8d68d1a13495987576934311a8da6f6c08c1936df47e763a03d7400698d46a85028d42c566eae5893582496344b147bf6c410c9708f4bb2b30d0e66781f5f7f7d14ee4d6faab8f611f42562313b97cd66b1d4fb150d0d473542df6924d9022ebeb5876dc66f32deaae2aeea5708040a8520e5c0b377e63f3a1f41c53b7f7b24051a544f201448159fa59324992ddcf3064ce4c946a180a4a0107e84537abe40283d49924205f43f1308b2212a8e616789e024257c4028f05d35058db90533eb56d5ddf2dd0f4f81c5da4d5b317f021ea2d1d4d8c2662e4b8d9b9c7ca36a7f1d99be0ff6de97cbb219ef67a557efdb4792d5b5b92c9872595524f977b53a9dacc62cfd64751ad268ac6609ebd0989e7578cfad453142313c19319b3dfdd0272f8c61fe0bf33ff1f01023d86c36c45bb0c95fd88806a860ab5b6236446821c1ae20c92a8a168b7dabc97436c8b3b1ef2b16c788c5d06d4013c5adfa405a4fe011da0c41e43b9112c2e4e46492481c1e796102363b494c12f808e94d129349b29324774a4c40391dfd947ad82f994cb0b193dec949b18dbaa50a3d12a07d9d2437807ca61e92f48aa3b0068c5f92c06eec11307e9af3ec8f093f1c9c7a70f7e72525cf3c99b2e2b983532760f39725e5304a4acacb212e21c97c03120f80c71bf0baf3cbcbc1677b79795135ec0fd7b2647b0910203f4c928cd7c9f412030bafb0baa5dcbeb8a4448cc68bb9b4ddeb2987e0c77ffce960cd4f713f4e340e5666f033944a1fbe12c1800f8b32c347e9032faf56093bd5f3339e2249a5927f025e9fb21e8cf97c20f83eca8c8be453e9e434e5f10cfe67c05c3c4ec97d7cf8c7071b130369d70e3fe7fc83cd222e78c1faff7cdbb47ea2f1fa2626130ef87f0302dfb1860939ecc40c85fd129b981897629484c2d64b984d9082b4290d9ffc2d58d3ccc46e1393ea42435504c60fd6ed5eb0807208498d4f4d4d75f1f48c1bef1b970af4c7d849f54cf5f48c871b239fbab8cd05ef01bf587f4d8daf428354d835fd227e6de253a1971aef19df860fdf333efe7b584092dfc7c72f226d0bf8b560cc897827eeddd9e0307be31cffb999b199b1b11b6bc619d72c08cfbc79fbe3d8c2c2ccb763a15bb80db6238fc51e05d7f46df069892df4022332b613627515b63221036d6c2c5ce4ccd8c2b7b14d7eff39ec80dfc53d8599a131f4401a77f1c2b81b1be7b8ced978c3ed66e9f9d2d252cff7fcd78edaaef5bf3175cecdf3afbabdfb7e29e27c0e84da302564a5610b734aa905a5a56c64721686bd9f537a1e84ff2e2d45397e0e94b8801f067d4aa90c1397be9f931a732490e6e2be28d2758eff7bfe2fbaee929f5e597c5a7ed375deae79f80ca6ce7e716be539ef9ab51f5c99b7d67febae274e179f3bbdf234a2580ea3982ae4545d8c078595e7ce41b1f25cf103f04c765e390df44a10c1248725d4f2420d189731026b1786bcfaaadb8d271c07448001d1d6d56ede5bfc6fdff6ff60ebc0c09559bb5c6b6e577aaf7573739b7753e408a2014798448e222ca0c43000e937b0162be83bc22e03f04a3e4505aaed107de3880ee10230967f5e716d8354ed21aeec360e198dbaa16e88de6e6eabe7bdbcda751eafbbdbd8f7cd9aa96b663db165cb96351f188dc6eeeecb43c6cb7d3aa3f1f2e5a1be21ac21ed36fecbd80d5dc87590406dccae66a0dc7879a81b3bc0755392eeee1ce98640da2c970086fbe2fc7eb59817c50b0a0ae2f1787b794151cbbc1f7ed87bd9f341c8044579d7b8bd3cbb66f52f7b7740b13788171515b417d43ba2b00b636e54e595a07858da0c445465b37807e45e3c845d11c5db1b056450330fd2956a30e6c97dd4238cb7b272932d1786bb86bb2c5d5d96618bc5a2bdd065b15cd242363c3c6c5946bd73d7c7b49780b57c316ce9bad0856a2da5ee9226f7d32552a8e95d5aed17927e82da06965a2e59bea0668ba5eb92c572e1021d76ec72cc05e31e9d5c1610939815907ccfdfd1aed487fc1f7fd015d1fbe9746d3f9da0f773455aa25f467065f47e6d52043d420a6cb48caba54b23b8a22a822e8d067900186b87ad9573378dfc89f18eb5f734d652c655f468ba9620286342d60f66388015d1e97429b6a04cd28e1a6b7b784372f59fddf1cbf647fd47c604dc493fbd8c4e8f1051de84946e370656cb152569a32322b02c8bb86bacd50ef3decc0a60dfd3f8b13535356ecbfe797ffefe51396a8cbf16030244f756ff72bf6ce1d7f898b1e8c1a280c9441a63d438ed1a973e79482a50db8d67b934043e387938f67499fd4f11ba322266e4e9c9c222215f6e377e5ee46260ab270bec4d654376e31eab282773ee6421533ef4fce81fd87a86adba5393051d6fb8e7bf020c00ccd184dcc60eee200000000049454e44ae426082
__btn_120x50_powered__
89504e470d0a1a0a0000000d4948445200000078000000320803000000a079efea0000000467414d410000d6d8d44f58320000001974455874536f6674776172650041646f626520496d616765526561647971c9653c00000300504c5445e4e4e2d1d3cff4f4f3d3d6d1dadad5dededc717170b2b2b2b68a88fe0000ef9493cb302fdfe0dea3a3a1cc8c8cda0101fbfbfbf8f8f8cecfcee6e7e6eaeae8c9c3bfcaa7a675716cfc3837f945443e3e3eb657569d9c998b8b8bd3cccbebe6e4aeafadcdcecbeaa9a8fcf4f3f4f4f4969695fe1919c9cbc7ba7776d7d9d5e1e2e0ffffffcb9393dd5655f1ebe8e4b8b6a1a09fd9dad8e95b5ad3d3d3d5d6d3fbfdfa575757d76665d37575eb78777a7b7ae40000f1f3eee2e4e2bbb9b5d58584e2e3e2ecedeba9a9a9d2bab8ccb3b2cac6c5817e7ae8e8e6606060cacac9e4e5e3c1c1c0bebebbeaece9e43c3cf5d7d7caafaec5c5c5f1f1f0534c46b1b1afce7d7cfbfbf9d8d8d7cb9c9bf55756babab9e6e8e6f46b6b9a9997676767b4b5b4fd2827cebdbcd8d6d3d5acaadedfddbbacab3a322aca5756e3cdcc4e4e4ee0e0e0635d57f20000ec6969aba9a6f47777f3f3f1eeeeeed2d3d1dadcd9dbdedbcfd0ccd0c4c2ededecbe6664d94342edcdccadada9434343f7f7f7eddcdc85807bc4c4c2e0dddde1e1dededbdafdfbfae9464692918eeeeeec67625c8d8a856a6a6a443d36bcbcbcdededadddedbebd5d4ebeaeadadada7d7873cfcacac49493e5d6d5b5b4b1e5c4c3848584eef1eccd6260f2f2f2b9b7b4908d8ad0d2d0ecc6c5fdfdfb2e261e4f4942dbdcdad3d2cfbe3a39c2b3b0d81b1bf60a0ae4e6e3d1d1cffe0f0eccb8b7afafafcbccc95a544ec7c8c4737373e8e6e4898580bbbbbab7b8b6afafad6f6b65acacabb3b3b2ca4e4da7a6a2c4c3bf79756fc2c4c1726e67d9dcd8d7d7d6989691f3f4f2e2e0dff5c4c46d67614d47409e9f9d221911dadbd8dadbd9dbdbd9dbdbd8f9f9f7f1f3f1dadad8fffffddcdcdadcdcdbdcdddbdcdcd9f7f9f7fdfffddadad9dddddbfdfdfdf4f7f3f3f1f1eceeec473f39dbdad8fdfffffffdfdfffdffdcdddadddddaf9f7f7f7f7f9f5f5f5fdfdffbdbbb9ebe3e2f9f9f9e6e5e4e38483bfbfbcf7f4f2dbdad9e0dcdbd36f6ee52b2bf7e1e0e59898c0a19fd1c9c8d6d1cff31818eceeeed5100ff7f9f9dac6c2e7c8c6ffffff48d8e4360000010074524e53ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0053f7072500000a8f4944415478daec587d5893e51e1e02efb226ad410a081c47206ca36032504170709049389485a020a149a450c6c706a9a0340d2a11c9ab0f0b31f1e324c390117a32cc223bca3bc6dcc6b7a868659468752acb733ce778eee7dd90d1875ee7ba8cbfcefdbecfeff9fdeedffd3cf7fbb1e92e5837ef80dc78cf97db7837ef3a5877e87b16bfece91b3bdfbd6d7c8d35ee54fabb0d92c449e9ab3dc7d538d6b32dbef060ccc1e7533d42cbc6d1d8f7f1b67993bda45736c914c73ddcb9e3675cdc163959ba29665161555ede7a6df4b819e71507adf01a0c0062a2a276798496fc21c69eeebfc6fc8c98e71711e380c1aa2b6dee770fc5beb78c3d77b4b51c9986830071da3452942eda34d929c0c9c9e9bacc25c9d2b1288860348e9216669a556a438fd44c1ad4323f7ec4b87852bcf36f20e6fa0ad83a05643bdf4d48935aa811e3d52dac47195cb14c8fd691ec8ad741e912f87a59298bc23a8fe870d6d58daebdf2e898becd96968cf4f3a31fbf65bc5e28654959ac0829c06221444849e4b43aadb8be8921c05b494b6ee522145c2e57e18ca8507015d53e085c6e0946b58b3579200f3b62f691470d1595144544b0826d8db385bf89c94b847740b256ab652b5ab55a7eb23639c81741abddc1d56a83aa498211c6570885207c4f94d694ece0bb0885fb6c8ca739727e053587737d71a135fb65e71686a96105354c393b53c3357c4a5bea3bac350c81a4867192c4513bcca8a8e192b0d41a1f0e275363637c64afa363662686e564806989537fa6a335b7706867324aa0b212f3304551a5169ba4b630ca3715c40e8c368525210dc74ce4bed55112ca5186b52a1be324b1b2fff34a657f7f57573f8eaeaeca2ee43fcf5a815a493886ec420afe8b2fbe40bfb29fb4fac9d645cc1d1b2454b407e54c8861ca31acc4920c23abec3250782c9fa3ea820fef7d1be356b3b9b3d3dc89b8972429d7afa774ee7d75ae1e39403a9d9d9dd660b608c98a4eb38132983b8b1a282ab8c84005c7133f0acf154e247980a2c21cabcc9de411e4315ab359cfb7313e2ae936779bcddddddd0505dd4f2c22ff6a38adf09a79f063d404ddcc811953b7193323c5e88e3214a12c3218a20aa20c515525f2280372728033609454611dc83c69411144ddddc6065be3e0f6769daebdaf1d88591c70f0e7c2c2c29480c57a52ebf4ed7dfa411d7a7a1da9f5ed460c3d492c836830fadabf23b33eaeb4944cedfabebe51851e6b71108394385be3e638be2a5f22e8d0772c595c5818306be6cc594e330f7a4dd6757474e8751d3a3448d06342d091d861e518564706117774946ddf4e1675b4331d5c37d112b9552db035cec8387ebcf478e23d5323fda73ee89fb076edc304015eb396883f168b8dcc598068346288c54c308a0b0a8ca41b29b6480a8cc63e745e9a32a5cf22fb58dc475a7da4248a443e216cee58b63ae3702341e4d4fb6e3cb9ff7e0637de79e79de71efc6091449022d61975e47275c0a09199466034a69f3c6961481cc478efe449f0635483d840bc26e7d0d1fc7d762abfe611e357d2571f4e6d68f0c3d9b87fea548beffde124f8dfb31f34c057a9541a3b3b3b7bfb86a45289a055a0dab9334e9c62347e179b93a32fd88bf7f1f5d7c7706f3af1f64387d01748ec25c1f6f676bb341a554bcbb106bedf149a6e83855fe3618bf12b9ea16541872b543c9e4ac5fb69ff9337c2c3c3efb78ef01b7fb9ef271e9fc7f498f9932c9aa673f83bb760a24f1de7f368062afe213265bd0fd1299ae6abd0ff84c7cb41547d483ab1840626f1f97ea9d388f1a4628fe6d4e6057efbf014ec829f7bce3f7c0ceef1f7d790169a76f9761ab2c9a92d35fb9ae9ac3dd87b4fbe9dc578dfaeacda3d7b68bab631df0e53be5d0d4dff55b32b8bae2559d6a9da7442032d1a3b7e333166af3ebc73417c1c5f62c14f2b3e787a14e14f877fe0f5b36414df6093054cd68281adbe61e208b19da66bac845f2d9d45e42f06a3f49348e2982e1149540bde85f17cb6ff545eccab3102b1d1c1c1e82056def7f418ac75101805f808e98c02a3515046d36502232887631f310f7b8dd1888d1d740e0efcf7985bdaae2304b42fd2f4eb907be890646d3f8635305e23c06ef6dfc0389e7af28745df1f9878e0ad2ea5f2893f2f59fcd4818963b0f673e5561c4ae5d6ad8858bbbe13a563103cb6e075af77dc0a9f4d8e5b4b6bb13fae257693128452e97898a6df7b91ce52eedd45aeb03668ab3216723d7692c4c3387692ff532b1987b71efee11f07eaff91f0c358e399ea6c4eb65a2de4a801e14bf8b0a8b3856a215e5ea31a3b1de1643f46d36a35e7243e37ea2330e670407084eaecf3f46359f414f5a7d99c4fc06cf994910b859c4f078f273dce0a4d7d2ae07b8b45c2ccb92bfffdf7ba95638d57d6b15838f1bb8180bce30616729a3ecf8ac07e49752c1259240a22b0752cab0e29a475e9e4c92f60b116b432dd3a16d345a3b2941837bf35772ee3302b4d969696e6dcd49460eb9b9006fa0ae9a435a53535c97063f463e7373a63a7f3e48bf57a9aac8618a46dc4259d47b25196865e9aac49d6411e7e93cc39070bf00d94c9e269cb024e238cb5d1af26bc361d0ed357cd0874a99257c9e5abea6d8cebe716555dbe56277771a942ab4aeeb211dbd11fca8fc1350b666be42e9930a2e5fd88b535a455850c5ab91c17e9217721257cf76207f25ddce952151107e37763e7255c5d35c375c6aaab6e97cbcf959797ffe98dc0e523b6cb03af4e9c71f9dc0b6eafbd594e702e0fa131528dac3c725e5e39b3a0bcdc9e3079f322dfcc2b3f07e13fcbcb899c7c0ed4640127127d46a98eb42f7f332f2dee28be4eeef131ae3302df087cc6759be2f49cdcd38acbaeb3b7cd26cf60e2f46736549ff5ae5ffe9f13b397076ed8f6c8e9dcb3a7e79c26c855e0c8650a0553e79293c19cb36751cc399b1b84675276e234e8391061526009b3dca58118b7cd8f9b37eb8517dcae3e3261c00718f0d9b0d4cd7b5de0b56b816f6f18183831b4cdb5fe5ab5f7723737b7d9977d264034300193cf041f52a0246100e9b7584b2af427609701bc928f8882a8adf0f976027188e213e39b65a1191a8d97a4bac75062300c7fd983e8ede6b674f6b34b5d67737b7a0c866f974d5c56f2c8ba75eb96bdfd80c1d0d373a9c470c9306c305cbaf42596a046da63f897015234d0e921b521a7f62510c84bc82644d3c3487a7af23419cc7f1247ddc3deafd048b8c9dc909010fc3adfcd0d495ee87defbdde0b091182cabbdeedd9e9f54b7f0cd98c6277083739396437d49b934917872cb9fa44880c4b5b412457b74a3623cfe4125815c9dcddc920435ab948e7588d6fde646b57e7a7982e9ee93dd36beaed359d31994c22a4a60b22645f9d39635ac8bc73d7874417c09a3e3b63eabd08ed57bd2246ddcb4ba9600b7860d8bd22d167820a31b38d09ad0ba6cf98d964eabd60325dbcc8c68ebd43f919a33f04825344b7832bf321ffdbef7487d8156cb6a8822d6657040d89c415527190945d21f28d6647f3c0264a83446c5e74d090a798cd4b843c3863f4a7cfed8d372fbfadb18831f66427b2456231632c9656c08c1c6087d86c368fb450fa8afe2763d1b3d647fd7bc662dc49053b8acd8e1e62bcc53cb6d518ac2868c85794181d4dcaa8e85f1a4b6e6bfcd0b2fa7ab785a2bb83ea31c6c13eb757ff78b76c4522e7e08c97478c434b83c713e96523c6d1a193d8e307df62e9adbffac485cd1f3f9465dff18fa87f18fe6f3c6ef8af000300197599270e2a057a0000000049454e44ae426082
__btn_120x50_powered_shadow__
89504e470d0a1a0a0000000d4948445200000078000000320803000000a079efea0000000467414d410000d6d8d44f58320000001974455874536f6674776172650041646f626520496d616765526561647971c9653c00000300504c5445dfe0dedcdcdaba7472a3a19cdadcd9e4e4e2aeafadd1d3cf717271f4f4f3b2b2b2515151d5d7d3dadad5a1a1a0b38d8bfe0000ef9493cb302ffbfbfbe6e7e6cc8c8cda0101cdcfcdc9c3bfc9a6a675716c8a8a8afc3837f945443e3e3eb65756f6f6f6d3cccb9d9c99ebe4e2cdcecbeaa9a8f4f4f4d5d5d3dedfdcfcf4f3fe1919c9cbc7d7d9d5e1e2e0cb9393dd5655f1ebe8e4b8b6d9dad8e95b5ad3d3d37a7b7ae8e8e7626262fbfdfacfcfcfd76665d37575eb7877e40000f1f3eee2e4e2bbb9b5e2e3e2d58584c2c1c0f1f1f0ecedebd2bab8ccb3b2cac6c5a9a9a9cacac8817d79e8e8e5e4e5e3969695bfbdbbeaece9e43c3cf5d7d7caafaec5c5c5534c46b1b1afc87e7dd8d8d7bebebefbfbf9c89d9cf55756babab9e6e8e6f46b6b9a9997fd2827cebdbcd8d6d3d5acaadee0deb5b5b4bbacab3a322aeaeaeaca5756e0e0e0fcfcfce3cdccecececdedede4e4e4eeeeeee645f59f20000ec6969aba9a6f47777f3f3f1eaeae8d2d3d1cfd0ccd0c4c2d94342edcdccacacaa858584434343eddcdc85807bc4c4c2e0dddde1e1dededbdafdfbfae946466c6c6c94918ceeeeec67625c8d8a85f2f2f2443d36dededadadada5b5b5bdbdedbdddedcebd5d4eceae97d7873cfcacac49493e5d6d5b5b4b1e5c4c3eef1ecc86261b9b7b48f8e8bd1d1d1ecc6c5fdfdfb2e261e4f4942d3d2cfbe3a39c2b3b0d81b1bf60a0ae4e6e3fe0f0eccb8b7cbccc959534cc7c8c4e8e6e4898580bbbcbab7b8b6afafad6f6b65b3b4b2ca4e4da6a6a3c4c3bf787571c2c4c1726e67d7d7d6989691f3f4f2e2e0dfdcdddbf5c4c46d67614d47409e9f9dffffff221911f8f8f8dadbd8f9f9f9dadbd9dbdbd9dbdbd8f9f9f7f1f3f1dadad8fffffddcdcd9fdfffdf7f9f7fefefef9f9f8dadad9bcbcbcf4f7f3f8f9f8f3f1f1eceeecdbdad8fdfffffffdfd473f39fffdfffdfdfdf5f5f5f7f7f7bdbbb9f9f7f7e9e9e9f7f9f9e59898e38483fffefef7f4f2e6e5e4f7e1e0dbdad9e0dcdbdac6c2585654605a54d36f6ee52b2bd6d1cff31818c0c0c0d1c9c8eceeeefafaf9bebebbd5100fe7c8c637e3c32100000ade4944415478dabc587d5c53e51edf90b9e31cd3da681fe545d1c148368aa3bc0c54986e212f71871812c844f31a4402a30c188a284dcb1551ccfcd42d65897a135c90780d257cb9ca0e1b636ebc93a206cbaedeacae95d19ddefb7bce868e5ef41fe3fb9ce7f7fc5ebecfef7bce73861f378afe01281af57abd4d34ac7fd8a0dcbfdceb55feba575242b86fdbc40a8b7cb1aca33ae60a565681d7840a27d4b48d961e8e3dfc6ae69c776a2650382bbc6d598a9ff8c6f63049cb1c5ffbc40997b7c5cc38bd3d36a53447a1283b11f72709f7da7e0d45396baddf503020364faa9d73d3f6d0e0225ce4e5fb5b841f8b7d350509070fbd7ba3cdf7e1a13ce9aeb097575bf3d1c93010c04e9e8c828a94ef6778067b7a7ade0afb3ad551713010e19ebd977464263ba92ee9b1987459cde1a34ee1d9e5aca59cdf41ecadb520eb199ccb799810a736bfee14e61434d39e2671c3b13c5d477a7e4f893340d7cf9972309ceb180faebaba7b7b6f3c3daeeed2d2e1a17a495cb853585c502614d3c4345ab41840a3818916234b69f55c7b6b3b9980bc33e9f09db96889dd6e9770c04a247649650018bbdd06b3b2d8e9b42ba023ac01397923529b343a9ac61f13ee151694e50a7f173332840f801dc33086a415c37876ccce4a0283615bd818c6aa440ecc509e44288444d2a98a1adb165eb15078e0ae30a560b286f21ba828945b4bd69e7678bfaedc8511334a3023c6e160c61a1e8655244162364cccee74f23123c9c28cb6d0cc9a00d8a2bd2b9c5f7094aac90f0cccd7382f12e065785605e63b7c674e13880670349a7c14688cf0c415d015aed4b6502c2913125b60b6491c0e2a6802c14faacce363f961d043e4229c8a579f39a38139060d32bf44ad05eb92ad76a96b1c316a2d259fb88f8f35b7611c943062f9a1368763044f73a60f8363415cb4855be622dc4a1d87b45bb7d2a8d4f79698a80f423bd647a54ae3318c2f6dc7f84b436ded7004ed30240e070bcdcf412cac4de1e0524d3c17e163cc2e6a1795dad5d5e5eedef55c0afa57c373ad5fe461778811bac8012b2c5d5458492acc2ee9175208a57db0802bb3c9a47de0f7c170385fd864b00f568518ac14f65874aec2fc8e0e83a1a3bfa3a3e3bbd895c1877f292d2d4d0b5e6982b8c360eae8370d19a06632a0d8d4618169428e63220eccfe8eefd06a8aafa8404b87a9bfff1ec3047b6120013cde55f8483c4f59c214749a3a33a24a4b83a32223a33c239ff29b61e8ecec34193a0d5040c6040b1803b29dce1c9935a089c89d9d3b77ef469b3a3bc80adc37e222ba932d1827bcbea5a5a2a565daacafdc66b5ac4cdeb4e9098460bfa80cdc1dc72de4851c8b05268e93c682bbbb5b5032067750dc2d967ea8bc397366bf83e68ef7a3523f0a1163050f25d25c85d7373520c4cc7af4cef3071f2371e7e38f3fde53f1590a9399861b2c0674bb06c090855cc660b1649d3debc8203b04f3d3b367213f8e35040df08d859f304a0ed095419963c278524153a64e17afd3e91a0ece9ae5d07d6c11326ed30ea2b44ec7532a955a3abda484a94bad600a5a05cabd7be3f13478c684c242933b15dec7575f1d876733e0bb6f7e02750193c9e7d3f974baf680b2b9f9b88e17349320da4025a8a1c921fcb6d73b35aca6012597ab5472330e3e7f67d1638b10487be7ef8f664081ac71795c91f26436411085bcbd6fc1429c6be17109124ade2768c92ee3f244e70882a784fa492eb710acf204aa2470cf91c4495c6e50e66424cc2a9f939979e476d00138053a7d8fdbca45e330cdcd4d8b4aa85842d7a226e7deaa397084c8de0fbdf797d01dc207e8d9b5fbf713446d43091d9692923709e21f5a6d36514baf81fb39579b85d280662d9d770409330a9af6de5e1acf63c2c9c0d9cc38fcd94bf7b0e8a5459ff9f941011d1bb2b7a1c95ff808cd1042abdb4c3e58f0f9cd307713440d996632836a896c3ed00b513d88c98c6732a1da8c4494b78f86537ac38fb9cde2c6be172bc02d1e1e1681c0fdd197c6619387c022808f90c122b058043b0962a7c002298fe39f9387bdd16281c61e060f0fdea7e423ed36a00470df2088f5409f6300277bf771d803c21b05d08d3f0ac2cf62cfff94f2e3a1e987f69ca9ae7eeea98c952f1c9a3e0e9bbaaaab6054575755814d208832134a4c028db7e07597555581cef6aaaa8a5ae80ff792b0bd1a12406f22884fdf20b2ab4d747487b593aa9c9babab99483894e5b6671da910f9c44f3f1faaff39f9a7f1c291aa5c4aae4a25a4a810e0cd9d54e50a554278790d2ae8749492fb0c41a85494b3f0b9511d05610a051214a12af70af14c363153753a97721232574e9374a190727aa825359c72b3e905cf1f1d12c9914bd6fde7fbba75e385d7d5d16870c1ff1b10d03bd6d1c0874eb468e8975a47439686ac201a5a27d0eac0056a5d163af9dbb0a795acd6d1b6a12a143415203c7560cf9225a442943c512e97731a1b935d7593e5f230f90d549137ca1b1b13e1c18867ae6ce3a067407f587f9327d620013974cdbe02ceb64439d4e4898d899de8f01b13c37e800d04f14362e25282dc10f6d70610c6e2de4b7e7f1e28ccdb303fe4eb1c598e4cb6a1de45b87e893467eeb53a597171cebb32a8166f8376c409d97150cd06b18db2e24010226467c0d6d6a0520e78c095c9e026e7c88adf4565e28733d001fd2dee2dce898e6784535809cb92af6f98ef3d7fc3759fb9ea8b6ab5baf183903563b26b42ae4f9f3ff7e26b3eef7fa846b8a800d310a3024f1db34ca12637a8d54c94512c8bf950a1be08c4ffaad5888e3e072ab48112037592a98a61aa3f54c8e38f855338be4b63bde7877c10f2b2f72ec9f9c545e72573bd17ee5a88ce60fabc97b7565ef0af5ff3bf530bd7846cddf5e4f9a20be7179f472892c0282203091917a18bc4e20b1720587ca168129cc9ce53e721bd1848b048600bb9bd5807c2795ee10dcba25e7bcde7fa935306030083015b57f9f86f0eb9762de4a3ad8383a7467679d75fabf45fe3e3e3b3706ec014200d4e8125604a000a20446610dc6f602f8aa03e05ba0cc22bf91c3110db89806fa62005291784259ad0a94d22ad1fb3b2c76c339b8db61eb0fe3e3eab16beb2ca7b21bba7c7dcf7cdeae9ab673fb979f3e6d51fb59bcd3d3d576de6ab7d46b3f9ea555b9f0dc5e0f698ff65ee3183032dc081d85c58fb2624c0b7f5a00ae47a484a4f8f42b43e9c329bc3f7f20d2d1bd032d9e9ec888808369bbd8f1d91bedcff9147fc97bf1881321176ff7a9f57e6d5affa36620794f645b0d3d323f6017b473aaac2084baf3c1511065b5b21915ed9cadc017e201bc1c94867ef4b8764442b1bdcc55a10664b84a251af770a4ad2ac9787bb87bbadddddd661abd5aabfdc6db55ed283373c3c6c5d4ebe73efc7f597206bfd72d8da7db91bb1f524bb5b9436c01088206674ebf55f0a0670b20d6cb55eb27e49ae566bf725abf5f2650674ec1e2901e15ea344cc8f4f2d589076dfefd1dee487fc9f7f501d610c3018fa0106ce18608de8f10131ce123306f449718c3811645788597a86288e35db0b678856007d0108eb87ed9561f9a30f10deb1e6bec27a52d8ebd80a861ec749615c3c006268407684c160885009c224fd98b0be976d93681ff4c4af388ffa8f8471789201461e831137426ae322865318b27ad648927e455c1c0af3e2ee0aebf5c3ecb70b16f0ef2bfcf8eafa7a9fe5ff7e38bf7f548e09a36f8b0b1604dc9ffdedc392856fe3f78403a6562c9848646d710a8f64dd6431260e49e55aa7f06c4e73f8d489c38967f39c3f4518f3f0f8d167270a4b79148953f8c5008e89af9d28f0f3f36c4ee15efb8822e7eb89428ec4f6e2d80f6cbdc37663fb44c1c81eeefdbf0003003055dbecfc19c9540000000049454e44ae426082
__btn_88x31_built__
89504e470d0a1a0a0000000d49484452000000580000001f08030000005416fad20000000467414d410000d6d8d44f58320000001974455874536f6674776172650041646f626520496d616765526561647971c9653c00000300504c5445ca0404d34f4f9c9c9bb66767f8f8f7d47a7acecfcee3dfdfd99494828282fb0000939393a74b4b6d6d6df4dadafd2828e3b3b2a4a5a4e5acacfd0c0c38302996938feae2e2fa5a5ac68786dc2e2eeaeaeaf10101f1e2e27c7d7cb9bab95a5a5afa1a1aa1a2a0d98383f6b6b5676767e1c3c3f1efefc5c6c5c2c3c18e8a8676716cb2b1aef47474dfdfdfcdcdcbdadadadcdcdcddbabae9e9e9eeeaeaa7a5a2dadad9fd4949362e278a8783e6e6e6908c88f87c7c535353b2b2b2727272453d37e0e0e0524b45b5b6b567625d8e8e8dd1d1d0aeaca9aaaaa9e0dfdfe75c5c999593e30000da0000bdbcbbecececea0000dfe0defef9f9ea1515d9d9d8d8d6d5ea2c2ccbcbcac4c5c4d4d3d2827d79b9b8b6c9c8c7bebfbdc5c4c249423bf6f6f5d10000a2a3a17b7671635d58d6d4d4aeafad9e9a9785817dcfcfcec4c3c1ececeb6c6661a39f9cc2c0bffec1c1e3e3e2e2e2e1d6d7d5dad2d24d4640c7c8c7bbbcbbbdbbb9ea0b0bffffff464646fefefefdfdfdfcfcfceeeeeefafafaf5f5f5f8f8f8f6f6f6d4d5d4d5d5d4f4f4f4f9f9f9f2f2f2f3f3f2fdfcfde4e4e4f0f0f0f3f3f3eeeeed5c5c5cfcfdfcfbfbfbf0f0eff1f1f1e4e5e4fcfdfdefefef9c9894edeeeed4d4d4f2f3f2fcfcfdfdfdfceeefeee9eae9eae9e9fdfcfcf7f7f7f6f7f6585858d5d4d493908d5a5a59edeeed5e5751d5d6d5f9f9f8d9dad9e8e8e7d5d5d5dad8d8f0f1f0a7a8a6aaa7a4f909095a534d7d7873d1cfceeaeae9f2f3f3f3f2f2efefeee4e4e3a0a0a0a3a4a2595a59e5e4e4e5e5e4e5e5e5c0bebcffc5c5d3d4d3cc9d9df5f6f5d0d1cfeeedee4f4842afb0aef1f2f1dededdfce2e3fe9e9ff4f3f3dfdbdbdfa2a2e73f3fffeaeaf53636fafaf9e08281fe8181ebebebfffefef3f0f0f4f5f4ddddddf3f2f14c4c4ca5a29fd9dadad7d7d7a8a8a7e10b0bfafbfae5d2d1eae0dfe3ccccf9a7a7eacfceb7b8b6dcdcdbc6c6c5ee7272f6ededceafaef7f7f6f1eae9c6c7c6f6e8e8abacabfdfefd5f5953dfd3d3dfd7d7f1f0f0b6b3b2d5a3a3d5a9a8f7f8f7d8adad595a5ae1e1e1f8c7c7ffffff19b36c220000010074524e53ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0053f707250000054e4944415478daac960950135718c763845610d0e8f31e131514574d82e81a889288b4a269452c153caa160f440e6945949804b209091b1213484c201102888ae085f778f650b4d7b4b5368ef4b2ad6db5b5dada7b6aa9fdde26541c33b583fcdef57dffefbdff6c8edd59d63dbf08b9c27b8f07cb9f98f8b1849044c475bbb17df875c1cb693324ec6e368e1bfec32f3d4306b715842e796c636ea8bc1305b1af8784847c4926cabb4a28d76bcc91b0d3478e4c4f4f3fc1e15cbdb3aa5d3d118c6fbfb3fec29dc47d1cce09a801def9ffc1967018e3fa5524b5a91397c7f4ec399aded45514ad7346d633c6f2a7d5ca7f512814caaffe5017fe0481c2acec8ce221fc68b0cf52c1917b8d5f2beae00b8bc5527473f06dc6c882934e28222412c5665f534a364ba22c96284914934741cae87863f13e79c715df6797ae7662af5b50fd40a7dba57e0065842442c9f3b5223c40e3ede3b17b5b784a25ee129e126facb8ea33ce2cbe0f55dc1a38302020e0cfdada5bd4b2e2ce14f1b6f08a3a9a1a06d682781c1e17626f67b46253a2cf5870a414632c351ac78cf96d74afb357a07aa504301a412cadc275a35177323448fd5468836ebb6e7b6881eea40ed4b3dcd0d33c1d283a66fe0bb4aa52cf1d9f71a4c7545e5e5656bee5dabba3020303af5554bc51c1b0b7ac6c6f39a60c53a2a628237ca492809200ca08331c29335225ea12dc037057335af32a9ff185d4d4cc058de48dbb3d187a4d526d61d87aecd85695cadb1fc09b6f906de89479a31d9ee8e6335117b0f1d0de09333231e7be67f9e8b132856c6b7b33b9bd3d2fcf60888d6d6e8eae3e3cd4036425252d48caca4af264793c4307a001cdcdb1670c792fb54fe7b7dd20533ed3ce39c758c581b1be37fbba46a3d16ab7697bbce88375b7717763a3767725c850abd454566a993d95da06510ca810576a3431a2181c6d830d78d9a6d52e15e15d5acd0c3066cb16af5b479242b269dd90673b18d52424b10643480a1711c44c720d41104f906b568856104d9932825843928488c82408212923163541790929138988999fc2b9eb7296be9e3b71c890bebf8eeedbefd2e7cf747069fa2c3e9f9fcc4f4e86b11c21244ece8759ba603ccc681656d0f8643112f3f3d1e4e9f968f1641056f357e09d7090cf95b39e38f8ed7373e76e9cfddefcf9b321f0b2b19fe194d5603058adb0e4a27c81758f21d7fafb01c43634a0068355b027f7203a68c5317c350274202f01b15304062b42d6d370ee74819c951b933a0cf8aeef3703abfb0df331e2544d3443f5e19a68f889701883af72403593e548214ea8c1711b3a9f034b0ee44ba2ab118aae81a3d52fc859ed11eb27b4b44c50995a4da6ac41c19861fd2f4e98a4da6132a9a03b5432b410fe489fa071ed322453e1a145e7b51b508209628769214a405a8763a50c9d779810dae150391c2a30be373ceec9f0f0d652bdfe23fdd1db53470407f79f1216d6e762d8113d50057d8f142db48fb7a39d7629b257e15580a4f69d285b6f4776bdfe1584c6e9f5849840f1a57a29120baaaaf44773c13875f39c148aa10e5a58f8d77fdf2caefb71d088706a599d573f948d5046cd6a142f4619544d36925219526906caa63220afa3e2d17eaa4e2c453f1fa2a8fd5290c0692cbe41e2a6d9db68da869bd946bb154edaa9a4e7bddde7c34153de723b69daa5b4b95c36333c9bdd6e374dbb5d34ad503acd2ea7d3667329cc3351bc4241bbcc346d36d366a5cdec523ae934e696ae9547163ec4e557fb0707f7297c243968e9f30fab911d0f213f27de07e396471b2f5eeec7f73f8d2f4f6d69995ad8457cc6d3d2747e8aeeb56be775d15797368d313e1e3436b25b191b74dcfbc2c2a997772bf51cff2f85ddc13f020c0091047cc009b04d990000000049454e44ae426082
__btn_88x31_built_shadow__
89504e470d0a1a0a0000000d49484452000000580000001f08030000005416fad20000000467414d410000d6d8d44f58320000001974455874536f6674776172650041646f626520496d616765526561647971c9653c00000300504c5445ca0404d34f4f6b6b6bb86767f8f8f7d47a7ae3dfdfd99494828282fb0000a74b4b5a5a5acacacaf4dadafd2828e3b3b2e5acacfd0d0d383029eaeaea96938fb9bab9535353eae2e2fa5a5ac687868e8e8ddc2e2ef10101949494f1e2e27c7c7cfa1a1aa1a2a0d98383f6b6b5676767e1c3c3f1efefc5c6c58e8a8676716cb2b1aef47474b2b2b1dfdfdfcdcdcbdadadac2c3c1dcdcdcddbabae9e9e9eeeaeaa5a5a2dadad9fd4949362e278a8783e6e6e6908d89cfcfcff87c7ca6a6a5717171453d37524b45b5b6b567625dd1d1d0ececec989898aeaca9aaaaa9e0dfdfe75c5c999592e30000e0e0e0da0000bdbcbbea0000dfe0defef9f89c9d9cea1515d9d9d8d8d6d5ea2c2cb26767827d79b9b8b7c9c8c7bebfbdc5c4c249423bd6d6d6ccccccf6f6f5d10000a2a3a17b7671635d58d6d4d4aeafad9e9a9785817dcfd0cec5c5c4c4c3c2ececeb6c6661a39f9cc2c0bffec1c1e3e3e2e2e2e1d6d7d5dad2d24d4640c7c8c7c6c7c6bbbcbbbdbbb94b4b4bea0b0bffffff464646fefefefdfdfdfcfcfceeeeeefafafaf8f8f8f5f5f5f6f6f6d4d5d4d5d5d4f4f4f4f9f9f9f3f3f2f2f2f2fdfcfdf0f0f0e4e4e4fbfbfb5c5c5ceeeeedf3f3f3fcfdfcf1f1f1f0f0efe4e5e4efefefd4d4d4fcfdfd9c9894fdfdfcf2f3f2fcfcfdedeeeeeeefeeeae9e9fdfcfce9eae9f7f7f7f6f7f6d5d4d493908dd5d6d5e7e7e75e5751f9f9f8d9dad9edeeedefefeedad8d8f0f1f0e5e5e4aaa7a4fa08087d7873eaeae9f2f3f3f3f2f2a7a8a6d5d5d55a534dd1cfcea2a2a2e4e4e3a3a4a2e5e4e4e5e5e59f9c99a8a8a7ebebebeeedeed3d4d3d4d3d25f5953ffc5c5fe9e9ff9a7a7504943cc9d9deae0dffffefeb0b0afffeaeaf4f5f4b7b8b6f7f8f7c0bebcf6ededdededde73f3fdbdbdbe08281fe8181fafaf9fce2e3ddddddf1f2f1eacfcef3f0f0f3f2f1dfdbdbfafbfaf53636d9dadaf5f6f5d8adade10b0be5d2d1e3ccccee7272c6c6c5cfcfcef1eae9d0d1cff6e8e8abacabb5b3b3ceafaef7f7f6dfd7d7f1f0f0f4f3f3dfd3d3d5a3a3d5a9a8dfa2a2fdfefda5a29ff8c7c7e1e1e13eba771f000005674944415478daac950950135718c723420582a84f838a5a4450d6234144d620c806298aa6569152ab56c5e281c825ad386a89d9103607d92426819883441210a278e2ade3d1507b58a5d2da6a5bdae9b4d51e62abb59d767ad0f736a1e298193bc8ef1dfb7dffefbdff24d9cd3e56b92f2a6239b1e54f07cb9798b19d0827a2eff7b9f19888f69cd737b613597d6c3c2562cbef2f078fecd8ea57f0d4c61c3f510fb6ce7c3f3838f87b3c43d45bfc381ee3b344566464646e6eeeb9849493f7d67749a741e39f8f6f69bb97713225e15c6ee459548efcff64116719e3b0f538b5a32713faf71f6fded15bc4ad0b73c31863d17352f23fc46231f9c31fd2f2bf602036903d113f860f0daed35627883cc66f5574f3b556abadb83ef22e63a445490fc4d10421dee96d24b19388d36ae38838268f8329a3a3859529a2ee4ffc907dcafa69031ec0ea674ae53ee92390d14434c9f6b60a34a0c63ec9ce6ab4b1491275824da285d56f7a8d3b2b1f4255b6060cf7f7f7ffb0befe01b5bab22715ec5dec8aee2685036981ec143607c69ece6895ba0caf31ef7815425fa5d74f98f0dbf801b7aec1ea350544af8762552daaebf54a3611581f4e842bd930e2c019aab73844295ba9ecee48abad72dff31ac7b87535356a75cdae2b7f8e0b0808b8525dfd4535c321b5fa500d428d5048294a0fbf92c25fe14fe9e10cb7a8f59442aa40dd1f7529a3b9d67b8ddb4242922f35e1376ef76318305db28b61f78103bb25124f7f044fbe4db8ad47e689f6bbe35d17e2da90b1734cdaeccefce4fcfce45f585efaadcbc63b3a3eceecea2a2dd56866ba5cae78e7b1a16e48617afaa5f4c2c27477a1db3d741818e672cdbca0297dad6b01b7230ecf5e255ff8537e727272e71468ac0acf6a97c96472f91e79bf57bdb06e379d6a6a929f324119d64c329349ceac31c91bf9895085b149264be427a2680f5c802e7be4f2957cb44a2e9b0d8de7cc59be79338edfc09b378f7aa19b71cdb1388e33e3061ebb0cc3e6e205188675e2056bf96bb1e64e218615e038c6c73a312c161762cb9a6179052ee4f3b1b9df42af7611ab3a8c336dd4a841bf8e1f34f8e677cf777373c13c2e979bc9cdcc84630d002029b30cce824b93e00ce621054cca4c0249dc3290b0a00c2c4f80c206ee5ab4126ee47244ac90883b2f2e5af4c6fc4f962c990f030f6f0cd69c376a341aa3115e4a4019cf78505362bc7f1a5cd43482468d9177b0e428386a4431fc6978e074691ab898cdd31801301e86fb0e6f15b19625e68c86fc38e8cbe1cec1a3bd8c3d5f17cfe03c56170f6f110a13d1a71ce664b262018cd3ea50dc012e17c34b31cc57c43b0188af835b9daf885826bf2d935b5a264b74ad3a5de18820c4e821df4c9e2ed9afd34960b74b8460297c90fe0613bb84402841430e2ecbb781341d8cedbaa5200dc8edf6754270d9ae0360bf5d62b74ba031e537e599a8a8d62a95ea2bd589bbb3c606050d9931706068e8b32a442dec070560a9659205ecb50880a5165d794060d90b8a54166051a93e0260a24a05ef2c48ad52094012afb65675a244c422db762ecca6181a601b18f5de3fd72b6f5d1f31368a5adde0d1cf14019057b701a426813caaae0808a83c81200f145179306fa052c111aa214900de3e4351470450824e53e1e3a6080f9bd341d366d40c66da21b6d136925efc6ee8a723667ceeb0d1b495345bad66037c373b1c0e9a7658695a4cda0c569bcd6cb68a0d7341aa584c5b0d346d30d006d26cb092367a233416abef88621e3f0cafbe33242828f4c987663158f9d2e36a0cfa4bef90fa322eff001ab73cd978f91a1fbe1e63f476f351bb3aaba565566f0f7faf71d80aa58fa263d3a6c5bdf4556ef41ca658e0d4983e656a603863ec8ed82eea53b647b819636dfaaa9c903e246755baf65f010600fe637ca7e4415c040000000049454e44ae426082
__btn_88x31_powered__
89504e470d0a1a0a0000000d49484452000000580000001f08030000005416fad20000000467414d410000d6d8d44f58320000001974455874536f6674776172650041646f626520496d616765526561647971c9653c00000300504c54459c9c9ba4a5a4ca0404d34f4f8282826e6e6eb66767f8f8f7d47a7acecfcee3dfdfd99494b9bab9fb0000939393a74b4bf4dada717171fd2828e3b3b27c7c7ce5acacfd0c0c38302966666696938feae2e2fa5a5ac68786dc2e2eeaeaeaf10101f1e2e2fa1a1aa1a2a0d98383f6b6b5e1c3c3f1efefc5c6c5e6e6e6c2c3c18e8a86dadada76716cb1b1aef47474dfdfdfcdcdcbb2b2b15a5a5addbabae9e9e9eeeaeaa7a5a2dadad9fd4949362e27898684dcdcdc908c88d1d1d1f87c7c535353453d37bdbebce0e0e08e8e8d524b45b5b6b568625daeaca9aaaaa9e0dfdfe75c5c999593e30000da0000bdbcbbecececd9d9d8ea0000dfe0defef9f9ea1515d8d6d5ea2c2ccbcbcac4c5c4f6f6f5d4d3d2827d79b9b8b6c9c8c7c5c4c249423bd10000a2a3a17b7671635d58d6d4d4aeafad9e9a9785817dcfcfcec4c3c1ececeb6c6661a39f9cc2c0bffec1c1e3e3e2e2e2e1d6d7d5dad2d24d4640c7c8c7c6c7c6bbbbbbbdbbb9ea0b0bffffff464646fefefefdfdfdeeeeeefcfcfcfafafaf6f6f6f8f8f8f5f5f5d4d5d4d5d5d4f2f2f2f9f9f9f4f4f4fdfcfde4e4e4f3f3f2eeeeedfcfdfcf3f3f3fbfbfbf0f0f0f1f1f1f0f0efe4e5e4efefeffcfdfd9c9894edeeeefcfcfdf7f7f7f2f3f2d4d4d4fdfdfceeefee5a5a59eae9e9fdfcfc5c5c5ce9eae993908df6f7f6d5d4d4585858e7e7e75e5751edeeedd5d6d5d9d9d9f9f9f8dad8d8e5e5e4aaa7a4f90909e5e5e55a534dd5d5d5eaeae9efefeef2f3f3f3f2f2a7a7a6a3a4a2d1cfcef4f4f3f7f7f6e4e4e37d7873a0a0a0f0f1f0e5e4e4f1f0f0dededddfd3d3c0bfbddfa2a2ffc5c5d3d4d3ebebebd8adadf9a7a7f7f8f7cc9d9dd7d7d7eeedeea8a8a74c4c4ceacfcefce2e3fe9e9f5f5953a5a29ff6e8e8fffefef53636e73f3fdcdcdbe08281fe8181f4f5f4fafaf9b7b8b6afb0aeddddddd9dadaeae0dffdfefde10b0be5d2d1fafbfac6c6c5e3ccccee7272f1eae9d0d1cff6ededabacabb6b3b2f1f2f1f3f0f0f4f3f3f3f2f1dfd7d7d5a3a34f4842d5a9a8ceafaeffeaea595a59616161e1e1e1dfdbdbf8c7c7ffffffb3924dc20000010074524e53ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0053f70725000005674944415478dab4960754535718c75f9408d62044d11bf75151e0454c88e893a1a68888a6858aade02e0e4486b4625162121e64f04216c40c2002221005076e1c75b4b52d7660b7566b2dd861eb684f87a78353fabd97a0f4c8d11ea4bf3bbeeffeef77ffe79dbc718275740b9fc3ef7832b0eec4d80fb8b3d9bc905e37b6fa5d17be9c749d8bf5b27188df2b6ff4f319d99ac30e7a62630e5bda859cc0f77c7c7cbe2562a53d85cd7119b3b858f2b871c9c9c9c7594d17efae6dcf9f02c6b77edef4d5ddd88b2cd671d8035cf37f03e3b218e3bab504b9b50b9726f6eb3781dada53642d71e3ea1863e98c7cc57d643299e2fbdff273bf8644a6efa23e920705506c2c66495dc66fe775f29dd168ccbb33f216e366a4172e643cae9f228ec78d88e046ec9041e336d1923bf2428c3073653b9cdc19f489822669e7153f608fa674ca8053b0fba546b3e7beaae071c3ed22452057216a1261038d3c6e8e4204cd15e90ef68a9b22cc4857175f741ba7163c802c68f11aeee9e9f96e69e9297271a79a27cad3c0e07335e12296880369be06ae988e3098be8d89245dad8b751b0b8f16d1188a0c8689135f9b30e01abd7bad103018402c2a3baaa9d0184a393c76c3620efbd50a8da6823d5bf3278874ac60f338a760f6c8d78834605356d47cd76d1cd0ac2b2931994ab6dd7873bc9797d78de2e29f8a19ce9a4c674b680af30b4da693a5a4c16420212ff4240b0a3d216122597ad20433690081b63139d7ba8d8313135397d413572ef465183055be8d61fb9123dbe57257ff17aef566c9e62e2b57b6bb39d479202298361e3df0af39a934b77fefe3a6ef9a06a2b5f5f584f6f6ac2cad36d0e97486561f1edd0ca4c5c72f894f4b8b6f4e6b6e1e3d0c0d733a030f68b35e6a8f12b45e211ade57c5dd66ac42c0583d105ba6542a55aa5a55df17ddf4b9507fa8be5e75a81c64d82b579697ab989a72d5ceb0f05a252c54e54a657858389dd542011d6a55aa956174954a39078c31c9f28d1b09824fb46d1cf56c27e3dbf804adc1e013fc65383e97588fe3787f62fdeab0d5785baa04c7d713041e86a7e2389f90e0cbda607b0521090bc3e7b6c1b9eb524c5dc799326ad4e05f270c1e72f59b673ab91a354f20102408121260ac4208452664c32c5e120c339a472b28382a12450ab2d1b4a86cb47c1a08eb04abe94a3828e048b1fe7e379f5fb060cbfccf172d9a0f898b2d43b4e7cc5aadd66c869089b285e6bdda4cf38f0711a6dd89766acdc2bd99a7d169339dc34f234407b36210f69c506b46c8bc0fceedcb916299e18963801f067f38bc7ac8183763cf558632541fae0c855b44a7e1f4550eab66561962c8632ae9bc15ddcb809001eb15a1d5088556c2d1eaa7a5583b6fd3e4c6c6c9725d8b4e9736c29b66ccd0cb93a7ca77eb7472e836b9042d8507e95334a95d8224727aa8d03dd56614a383dca65b8a6290ca665b2341f76c3a8476dbe4369bfc3cdc3c8fe0a7fcfd5b8ad4ea5fd4c76ecd1cebed3d74baafefa0cbbe47d54019f4bd62b4d41a6245bbac62642da3a31089adbb50bada8aac6af5798426a9d578248ea28bd46214292c2b531fcb04e3c41d710d24430d345fff77febe5350f3d988b1fee4e21a977e221da194ca75283a12a59095e9484ca688c529289d4c81750d198df693359162f4c90992dc2f06099c82e817246496b595a22c74d35ba82a999db22ba8851f0ffa62c4f48faaec14e550581c0e8b1ebecd5555551455e5a02899c2ae77d8ed168b43a69f8ba26532caa1a728bd9ed22b2c7a87c24e2531af74a93420f7212ebd35d4db7b50ee63c9402b5f78580de8fc087573e20f306e7cbcf1f255ddf83ed2f8d2ccc6c699b93dc46d3c2b49d3cd66d5860d0b7be8ab499ac5189ff1080ae855823cceb8feb0b0eaa4bd4a1dab03ebf89ff8478001000e5679c8be0d6f460000000049454e44ae426082
__btn_88x31_powered_shadow__
89504e470d0a1a0a0000000d49484452000000580000001f08030000005416fad20000000467414d410000d6d8d44f58320000001974455874536f6674776172650041646f626520496d616765526561647971c9653c00000300504c5445b9bab9e1e1e1ca0404d34f4f818181b66767f8f8f7d47a7ae3dfdfd99494fb0000a74b4bcacacaf4dada727272fd2828e3b3b2e5acacfd0d0d383029eaeaea66666696938f5353537c7c7c8e8e8deae2e25a5a5afa5a5ac68786dc2e2ef10101949494f1e2e2fa1a1aa1a2a0d98383f6b6b5e1c3c3f1efefa6a6a5b1b1b0c5c6c5e6e6e68e8a86dadada76716cb3b0aef47474dfdfdfcdcdcbc2c3c1ddbabae9e9e9eeeaeaa5a5a2dadad9fd4949362e27898684dcdcdc908d896f6f6fcfcfcfd1d1d1f87c7c453d37bdbebc524b45b5b6b568625dececec989898aeaca9aaaaa9e0dfdfe75c5c999592e30000da00009c9d9cbcbcbbd9d9d8ea0000dfe0dffef9f8ea1515d8d6d5ea2c2cf6f6f5ffc5c5827d79b9b8b7c9c8c7c5c4c249423bd6d6d6ccccccd10000a2a3a17b7671635d58d6d4d4aeafad9e9a9785817dcfd0cec5c5c4c4c3c2ececeb6c6661a39f9cc2c0bffec1c1c6c6c6d6d7d5dad2d24d4640c7c8c7bbbbbbbdbbb94b4b4b6a6a6aea0b0bffffff464646fefefefdfdfdeeeeeefcfcfcfafafaf6f6f6f8f8f8f5f5f5d4d5d4d5d5d4f9f9f9f2f2f2f4f4f4fdfcfde4e4e4fbfbfbf3f3f2eeeeedf0f0f0f3f3f3fcfdfcf1f1f1e4e5e4f0f0efefefeffcfdfdd4d4d49c9894fcfcfdedeeeef2f3f2fdfdfceeefeef7f7f7fdfcfc5c5c5ce9eae9eae9e993908df6f7f6d5d4d45e5751e7e7e7d9d9d9edeeedf9f9f8d5d6d5d5d5d5f3f2f2d1cfce9f9c99a7a7a7aaa7a4e5e5e4fa0808eaeae95a534defefeedad8d8f2f3f3e3e3e2f7f7f6a3a4a2a2a2a2f0f1f0e5e4e4f4f4f3e5e5e57d7873f4f3f3d4d3d2ceafaec0bfbdeeedeef9a7a7fdfefd504943cc9d9da8a8a7eacfceeae0dffffefe5f5953a5a29ffce2e3f53636fe9e9fdfd3d3fafaf9d8adaddbdbdbe73f3ff7f8f7e08281fe81816d6d6cebebebdddddddededdb7b8b6d9dad9b0b0aff4f5f4fafbfae10b0be5d2d1e3ccccf1f2f1f3f0f0f3f2f1c6c6c5ee7272f6ededb4b3b2cfcfcef1eae9ffeaeaf6e8e8abacabd0d1cfdfd7d7d5a3a3d5a9a8dfa2a2f1f0f0dfdbdb616161d3d4d3f8c7c7f8f7f7c125e99c000005854944415478daac950950135718c71745a880417d46c078554439821a14593982a6088aa6851a5bad78503c10b9b4221e84242ce460137210041222c86550bcf1c2db5a69add5deda5a43457b4d5bc58e6da79db6d3ef6d82e2c8d40ef27bc7f7bdfffbf63f3bd9cd3e22af270a8289e0bce783e8498cdfc2f7e1b3eff7b9f158e7dbc96fad9bcd4ae863e300ef4d9f0d701fd59e782bfdb98d895be26ee406bdefeeeefe1d192fee2db708bbf1695682afaf6f4a4acaa930ff2b0fd738154e03e3076f6fbaf330fe8a7fd8a914dfd378dbf7ff93c03acd187bad21a9fc6e5c9b3860c0043abfb748da1253bc1863f1cc42d923241289ecfbdf0bf3de834462e8a6fe278f0ba058531a26b61bff5dd0c5371a8da6e0dea8078c9b062fec48d82c6f59229b1519c98adc2981c63a882547640768606649765a5933f11545fee2ae3b7ecc1e65f5b4812761f773a572cf2355c666459838b220968c739093506f62b372651c68f6883bd8cb36701234b8baf48ac3b8b3e83154519beb081717972fabab4f528bbbd4024e811246305f19c1f1e7e4425aa864f3bd7184c1f4ed4ca470b536de611c72a204a32fd1eb274efc73c2c0bb78f76e31a0d78358527542c951eaab0936bf6931c15773944a0edf07248e3df2d9c449989d0b41009baa12db438771a04d5b56a6d3956dbffac7785757d7aba5a53f94329cd1e9ce94618a0b8b75ba73d5945ea7a7202f76a18a8a5d206122557d4e0733a50701dbe8ac6b1cc6011e1ed1179bc91bd7fb330c9c2eddceb0e3d8b11d52a9bd3f817dbd59b8b9dbca9eedb6855acf470660e36163ff9add99169d9616fd4e3f07fd573791eded5f8b9c9c5a5bd5ea20abd51a5a7b64980dc8888bbb1897911167cbb0d9860d47c3add6a0f3ea56272711af3d926c5aa148fc352d3a3abaf33e18ab7c1292e472b942d1a8e8ffa6837ed79bf736372bf656800c7b15f28a0a055353a1a80f8f6894c342512197478447e0ac110a706854289687e32a857c3618cf99b374e34692bc41766c1cfd4a17e33b82499264c60d323889cb9d4ba673b9dc4e327d55f82a6e47a790cb4d27496e38b793cb0d2685dca40ed85e460ac3c3b9733bc0ebb69828f5ca9d367af4e0df260c1e72f3db97bbb8299ac7e3f1443c9108c64a845094280766c1c5c930a3795841934551288a9783c2e6e5a0a56120ace5adc29570218f10131ede3fbdb660c1b6f95f2c5a341f123bdb86a8cf1ad56ab5d108211be584188fabb30fdf3f8a0ea8eb51bdda18723cfb02ba60c439fc3421e8686b2c3af06a88da8890f1305c7738514c2445248f017e1efcc188da21631c8c3b5b17ca507ba42e141e114e23f05d0eaf65565902c863eb70de8e2e6741c882f5b2d05a8442ebe0d2da97c444c5d64d535a5aa648b56d5a6dc64837cc98a19f4c992eddadd54aa19ba542b4045ea48fd0242721124af150a0cb8acd28560bb959bb04c52285d9bc5a882e9bb508ed364bcd66e92531416d0d78c1cfafad44a5fa51b5efc1ac716e6e43670c1ae4e9f9a20a5305fdb8002da99c5c8976550a5065158e214850b90b65aa2a51a54a7509a1492a153c591453a212a0a890aa2ad5be6c3121bbb333b18962688036c8efdd7fee1551f7468ef3a31637d8f5fd9908a5d6ad4531512895aacb44022a5520484599542aac1ba81874886a8812a00ff753d4210148e034155eb7621faf39ed345d8e9ba19cae919868938c5ef8a9e75723677c5c63a2698bacdc622937c0b7b9a6a686a66b2c342d91990c1693a9bcdc2231cc453112096d31d0b4c1401b64e5068bcc44af0363896e8338f0e9c3f0da1b43dddc3c9f7d6866a1e5af3fad06e2bf747e614fc679bf8071cbb38d97aeecc1d76e8cbf6e3dec5d9bd5d232abb787bfc3d86b99b287cd9af5eb17f6d257b98e394cf37d9ca706f629539d7d983bb6796f11f7295bbc6d8cb1266e45b2471f92bc224ef3af000300e6487046c5dd264e0000000049454e44ae426082
__catalyst_logo__
89504e470d0a1a0a0000000d49484452000000ab000000f40803000000d3ee26090000000467414d410000d6d8d44f58320000001974455874536f6674776172650041646f626520496d616765526561647971c9653c00000300504c5445898683b59694e8e8e7c3c3c2ae6d6de26b6bdf4343de4d4de3dad97c7a79e27272d9d9d9df3232e4e4e3dd0000c8bab9f6f6f6bcbcbbdf2b2be6e6e5c1bfbee2e2e1d1d1d16c6c6be4e4e4df3c3cb5b4b3e20000afafaee8e7e6da9897dc17173c3b3a9c9c9ab78483d9a7a6d9bbb9d6d6d6dededdda8383ececebded5d4df2020b8a7a5cececdeaeae9de5959e0e0dfe8e6e5a5a3a1de6363e6e5e4df2424e7e1e0df7a7a746e6b4c4c4bdededcd9d8d7f0f0efe0e0e0c9c9c8949493d1ceccc7c5c4e2e1e0d1cfcf595959a7a09edd8e8ddcdcdbdcc2c0cba7a6d4d4d4f1eeedb0a09fc45858b8b4b3e1c9c8c97c7bd4d4d2dcdbdadbcdccd6d6d4eae8e7dcdad9deb2b1e3dfdfdd0a0ac94948c8c8c6c78b8ae3e3e2eeeeedeeededcc3736e8e3e2eeebebf4f4f39a9592df1c1cc66866b2b0afaaaaa8cdcccbdaa09faaa7a6d7d1cfaeaaaace9593d3c0bfdcc7c656504bccc9c9d1b1b095918faeacab47423d625f5c999997cc2c2be0dcdce5e5e4d62a29e7e7e6d23333b9b9b8d42221d5908fe9e9e8c71414dddddcd73b3ae1e1e0d90e0e2f261fdfdfdedbdbdad46e6dffffffcb403fd5d5d4d80505a6a6a4d3d3d2c6c6c5b7b7b6eae9e9979795d3c8c7727271fcfcfc221911fdfdfdfbfbfbf3f3f3fafafaf9f9f9ecececebebebf2f2f2ebebeaededecf1f1f1f4f4f4eeeeeef2f2f1efefeef1f1f0f8f8f8f5f5f5f3f3f2efefeff5f5f4faf9f9fdfcfcf9f8f8f4f3f3f0f0f0edededf3f2f2efeeeefafaf9f9f9f8fefefefdfdfceaeaeaf1f0f0f5f4f4fbfafaebeaeafbfbfafcfbfbf7f7f7fdfcfdf2f1f1fcfcfbf6f6f5f8f8f7f2f3f2eeefee564f49f6f5f5edecebf1f2f1fafbfaedeeedfcfbfceaebeaf3f4f3f9f8f9fcfdfcfbfafbebecebfaf9fafafbfbecedebf4f5f4fcfdfdfbfcfbf5f4f5d7d7d7fcfcfdeff0eff6f5f6f8f7f7f3f2f3fbfbfcebeaebf2f1f2fafafbf1f2f2a09f9edfdfdfb2b2b1d0d0cfeeedeecb5250e9e9e9de3737d42f2ff1f1f2f2f2f3e01111f8f9f88e8e8ddd0606e1d2d1bc7170f4f4f5dc1111cbcbcaf1f0f1c0605ed5d6d4e7e8e7b8ba43a0000032134944415478daec7d095c1457ba6fdb5cc1a66d04bb9b4505411431610938b1630b0a2e6d1883891ad490c6cce88c82316a4421e910a2433a82332420c69666695691457615515605e3164d6212931992cbbd7367446e70eecb33e6c697f17ddf3955d5d50b0dce356f98f79bafaa4e7de7dbcebfbe3a555dddd439087efb8f43827f621d96ca53ef0a0e2f49120992e373c73456e9c29dde4b0e1f1608ee8a446e3bbddd6e178c51ac2dd987f71cbe7b0868215d160a96782f1c1a83585b32054f899201e8add4c14cbfbea8f06958b9ebe67da8658c616d6949f6161d4a3e1412df949b7b3a975081d605e02626b9c95ac612d616bd60c9c24387a6a974a65476ffd6a14302ef5bbf6d1933585b06044987927d3219840d4f3cb9ee173fcf27fc472ec9c977f72ccc6d1923585b0a058793930f16e99126acf59a3d7bdebcd9b3f7fa2e5f8082815bc90b772efcaa654c606df952e0969c6c5700b8aeaef49ac7a3d9cb3bf41dfaf2f7920fed09194d667f72ac2db97797242787e7033d9140207a25f8fafa264072e7dd6b4371ded6e4bbde2e5fb6fcddb1b6e4de7eea50726a414141ed6a84e735f389dadafcb68febcfdef34d68ebc8074581ffad64819b7ee4cc0a7e6aa8faa4bbc95b9c01d18e79f31c97adac6ffbac0db3d9565b5bdfff593e053b909c9c74e8abbf3bd6af92939293e59595fdf71c21a9bfac2c2800a005f5509c246c7e4125904bf2426f775dcbdf156b8baec87b61b20ba07912cebf6fffc705274f9e5999b06cd9b2b54ff693ce4ac196df4a3e7cf7df73ffae58733fdf92947caba9ababc1cb719ed7d9ca82da9fc3f5e5e8e808dbb29505947abbbabaeefb1cf2ae1929b19658c5b31e15656646b92eb9eb230330cb01dbcf2b4f15dc6380922de1522d62ad04aca5b77c9276bb6666f2bcf346c2aab9ebfdd423a5253e3e6a67e7bc658e8eabbb2a6b012a1fac97f329a42e67676799cf5d334fefa4292d36b0b61cf43e9cecf388e9605555d56ac075b6bff29708904fbeb57865758185769a85e3dda7ee9adec704fc87a1afbdef82cdee6940bbc9b69bb767c51c4ff7bb4dcc381b669d36ede0f1e3c7cbbc1c1d97f774f57b399ad3935d485560a36562b0db2d1f9fe4a7769b80e563d5dd724bbe75bfa8ec9153e96cc779bf74eefa85055447af7ec4ea6ccd296c8b4fe292cff960053ca8f94f1df2b1cb23f411160d1bf33efa286f6303156c24823cb27ed4d0404c3e025d43037569608a06f00113c60b5c1a1ada01549973d75a4bac8ebfa4896dc0969820a429d8d43e3e3b0b7456b1e6ea8bbc7d6e3d00b36a58085557139629b04ec57979c63d2d581153a11eacb06a82a3e3da2f9ccb9659c13a012f2c67e72ab6097ed4db3e495d7fe22556604c6b418af7ad5ba5454545d50cbeeaea6ac69185ccd4abab1944342aada2809153cb6a222b3bde53b5d271fcf2b29e13f31cc75b2c2bab7a085d2adb489b648ebcbaa8e8cfb25b6e45953a6b58f55d52ef5b21a5a5a547ab1e319ddd31de717943d586799650c7affcc2ba4f1e0091dd4a6a74d65bc39a5fa506acc78e1d2b3dfe88e98b95e3c7cfdc781cb05ad2bd3ceb3e45c78e5d81bc3695e5e75a62cdcd2fd302d646a0477d1bc89b307efcdae6b2a3cbac605dd76cdde728e000acd7cb0aac612dc80bf3bef55e4d4dcd828d8f98f29e771cbfece8c6a29996501d9fcfb3ee535a53f3b5ccc7cd90370cd601c86bcd898a8abc474d27668f1fff8bbca2272db1fa7e3d8ccbb18a8a0ac8ab7018ac4580f5bd72a06aee2ae6288fdbe5b11ae3b5cf3366b479a69e5f7b4127282afa3ac1b20b94565b12c65c003800ab6178ac21ef353535c55da82e825b06dcbb8aaa9b2f143517155da86e2eba402417aaab9b9b61050e44a0058b0bcdd5179069863a68802e10633080486079e1d89cf1e3676f686e14ce36833af3c3a3d5c4b2bab91a5a007bd21e546b00882cc46dc8565e4b4a4a9a8e3e6a2abdb96c7ce8da63a571afcf0be593af7fe3702e1525251f8e94d742a0478fb57c7568e8b213471b4b56878e372e33851f940ee7520e3820afadb6b07e6a30f81f2b2d85956ca5c74849f95246708c14c7182d3563585a3f66b4a2be0b8abd12e656941e5be0654c6ac29c9c38c6891a323b12f6589cc1bfd56e84bc7e5a6c301c7be474264e3a7473c1b1334f8e0790cb66aeddb5767b4cca1f3f3833bc4793c1503c425eb7b6b6b616373e7a82cb7a4163e3194ceb78e503a1a730d03f6ec1021b0e25adadd701abadbc6e0d0c0c6c5df053d12f30ad5e8171401535b64d0b0188ec3db7ebb6b0eedbb76fa8e627a29f93b4ce29ac1885ad0170d8ceeb7b5b1f088543153f0d9d58171a14149a208c1b8d71b1502884bcdac2ba2525c55358811f5e1f9c80e244f989131fe0527ee203283fa800ee0394a3124aa8967f50517e02e420c10a6c27c00cf90a12a28209535e7102d21a143ac7508ec6e08b42107f40ea108484454370fea0d833256564ac2929d89fcacbe32801032c29e258591c22e51bb162625a4e5ccacb796ac2af0bc2b44a4bca5977aaa166e5fc266109041c762360954aa529711be083362e6e435cdc871f02ff61dc871b36c44109d2a6b80dc07c08aab8a60da8c4d8b0df802b630f2c56400d9a3874c14871971382a00fbc1cd8c458639ca60d1bf0437d4313ba7cd844037fd8040dee031c23e555a3d1484bfe266a828563add004486b50c2139787f336ddef0320a3c0aab1d9e4b00069bd6938d7f604c43a67a8c4327a93151721e44cb6c516d6ad5b24ee128dbf7f61e14dff42d8f9175e2e2cc4dd4dc25fbe5908027fff9b582f41098afd5902256a89e4b2ffe5cbc8117fe0fc495abda406f89c27a6343c616fa2e565264e21fa965cf6944824b2ad6efe36b0ee564bd412cec98c0a2d6b85b4b4626ce6c0a45568db8a3908a014c0613baf5b76abd52c568ee069060a7fa630b0528633f02d2d14065644d2ba57dd6a1ac4df2c9851930240006ba12dac72b95c5dfce8e979af2007486bcaa81da48063a4bc46ca23e5264e864701b57d024075d82b0f1cb58746ab95cbb6286c619da6d56a238b035baf5f2f6e6f6f6d6f07afebedd703db03db5b8b5b8bdbaf17b7b6830294adc58181edd7dba10efa567ce2696f0dbcde4a5c5a415f4c04adc5182bf07aa017400d7a591a587c1d82a115442a0e8450b06271bd1dccc0bab51dfcb02dc01a66b7e5b0cdbc86858569031f35e5405a1d1cf6060b47efe20e4064bb6df6d769c1c1c1618f1cebbe6524ad9a87709104076b6536f3ba6d5afac0c0c0d0103e190e05c24638acece328705fce100a1883a11c6a8012d4e4e4101bb4004b10eccbd947d31a2624fa405e3cacc3c28b4fc24000f5407aba6cf7611bdf0b764ff34bf70b26f08c34c42b4de543968aa12726ac5c3e732dd0cc95f79ea4b2b9cb006ad0fb12f390fbac846477ea74bf74bbddb6f20a5881d05cb8cf581a19213f306322344aa5f7d62e0b75305290a3af2758cc417e6f9a9471119a86e16208f77106fbf6c90187dd08794d4b4bf34357247ec9106dc858e3898513d68e7730a77912a1d0732f72efabd18e1f8ca2366d611f6b244ff3f393d9ccebb4cd2a559a9f99af35debc264c99b38cc9e581037b9f7e7ad7d34fbff2ec8150075f401883e257e64b85fb86f5b624ad2a4d65372256559af0e169c2327b075882f64e8a77fd6bd42ca558ac54ce8a0a78ff398950ea85aaf7d59e0f1550ab5265d84db389f5366055790a1ff0bc086fda902753b2d2b9be41f6f60e0eb365f151cab430393c5200a9d5da743fb934e59e83bdbdfd5e9594f5f5348f6341d86218e0908d8035232343055f1f1ec0f7ae144f20b22702f8568f75aca4a408e9cef301b2318e80c6e195882c71ba5c224d49f9c5ba09f7264c783225059eed53a47b495ae5c49c149ee085c139c9031acf93ab822e1880d8ceeb66c49a812da45092528ed991926c52deb61c926a3f7b926b865622954e58bb6c5e2866d22168fcec841d4f4ae790b42a3529f8ed888b4a5d599e8dc830b81f0d5671863823e5a1682d027bda550c4827cc9c676f4a4109b371f77e302058e93861f451d3c58075f3085881a40f419a048072c02e334da29990e0606f9df68a21e3abe1d29b33eab8e980c336d6db53468755c232737d01cab3af8ae51af5dae190dadb6f1f0097e5a00f9af050586f3f02acebc6fbae9b4bb2bad6dec37e76fc2ab5e6de78e0865bec7d9f94ba676c77b0f7084d1f25563f8ab5d01656a552392256b597bd47d04c0d6475070079364025d12cb7811417c7d735c1b3ececed3de6c94787354da9ec1b29af80550920709d3b573a9739d3b464ea73c3f67a008d5f3d77429087c70184ea0b786c53e89cb9da5993c0ca5742a31bc34a695c5e5b730956a5edbc4e99d2d7d7a7d4680850d834789ea5b44029c8e07b7b58d4a403d8fe6c47c0f0aa4a2d49f018991ce648c2329ff6f0b0dfa121870d01198c1857c3248701ab999b0640eca6d8caeb948314ab6d92f865de7f3a8822b053aa25be1ea3a1a0099274d767e1e8d235a32006abadbc1e9c356b56df8881dcb51959d94f3b78dcf170f07d5db2dc039891578fd06089ea5538c404c928b0aa00c8487945ac6c2c77137ccc8eecddd5c1e280173dee008439310e77901979f5f092abfb9ef6b8e31033978473378bcc14b40506eb655b58333333fb889bbb295c96e172a25e031843efec551eb8335af2d821091b04f3656acb54f09a214da80088dd14918dbc1e4c05935912890657778919a1d45dc354e40977ee1cb09bf4eaf63ba327877475c6a48990588d4423b120402921e135d07206623d78f853db58a3323112c92109406a349d128ed14856d9dfb9b3cb3533d3e1ce9d89a35ed7aad35d0f4cbce3abd630d8988608cbd609f08c28c46a3baf5160231905a977dc991814e0a7dd3571e29dd1af0e31ea985d772686ce97583967266c46545414601db28535dc356b5458d3674f9cf8749ffcf5a0890f4533e5e9f1f6133d5e965b467437e132b2b2a26ce73535f5a02c3b603458e7d84f9c18e1a75efe705027860ea867bd3871628276a4f8e2acace7ec526de53515c9459c2657c3571096244606ce3d29d4eaf7274e0c729507ef7d48ac1357cbc5d06d42d3e8b71c8cc6b5209170cda8116bd6f079adcc121d26586599cff565a44bd4d67a29cb403f9dbcb74f1ee33071e2e4875a7ce5e9efc3ee397e74b5da6a5eb320af56ff6ed8f2a5ccfb10819a1afb1cdc2f32952a2dcd24dd4c624bd469f3264e9ea492af9efc905027cff6d36685063dfb32935135975e1e6eb511abb5bcb6e4c67adf4a752158176732a44cd3aa87a18c0313276f1fd0264c7e5872104bc411b258a55c6d9bc4aeaeaed6f3da922bf7bee54249b6660d41fad7cc3599b3c4695aee58d9e3c750ab62274dcad2facd7e68ac1357abb5e2be8c30a6abb2ab84cfe19e6075b196d7169de06e2a83d575d69a59745d43deef15a7055b1eb65639e8aa5267cc7be3a1c16ed7aae5232595cdab35ac2d5f1d7223380ffef8fd20ef35e4357db8025c55ba9cbb5a6929d786c9d5ca030f0d75f2cc60ee7ec264932d79771d895a0958b3ad606dc9edf33e8850537ffc8dd38b99b3fa00206c6be01112372cd6f465f859765e65e8cf263fecb26bbe7a34340cd696dc3f097c08d419bf71727a7110e12df27df6c0bcbddbfb4c08d26b8ab72fe8670f4dbbd2d4566edda3c6aacb7a0a2e291797c77ff3aed38c5457e5aced41d39d90de7ddb2b0abe27e0420ba572555aba56c2cbebc3639dcf032a319e74899abd8489a0cf757010b09a3d67b5e4560a7c648075ca0bef3a3db3f9fe9a35afac7fd789a1771dde579a9358353f385222593767e52e8787c73a29cde443c5ca470201ad1c04ac32f3bcb6e81bbd5311eb8adfbcfbd696f0bfae39e0c4a7d7de578af1174aa55829264895ca9797cff49a1dfaf6638ffdec6fa0ed2acb0ec05d5712eea396c16a9ad796dcfc836e32a029cf400fb0cb9cf50ac927b300bdbd48ccd1cb3bb6fb3e6bff167318dfadff61faaf00f1432c8f4dde1ecc3d56f092a936fb20575bcd6b8baeebf07b88f5f1df38bd35c555bcfd0727337a56298e41940907de9ebe9eeb1c4ea680474b0e01b66fae6c0f46acb13291e9f7d8dcfcaaa752016aea0ce8add9cabe6fcca13abdb3cb2bf4cd1fdeb5903badffcd4bac74fd0fdf8e0ef1b3b38c8f00ec1dd6f878453fb390e9c3bcda99e535b740b34726b393a5fee8e4f47880f8d5e94ea3a077defaddbf8cdbe4b3d4e735bef4bbf5ef20629bcbd331a3babd12ac90d70f4db0eaba644900d5e5f6334eef443f27de3502ca775f7be15fc62df5b9b5655ab4cc2e5bf6aca5c577eb4992add2638f4d9a2fe13fa8f29f3598470dda65fb02020262cdf3aaafda7cd80eb04ef99dd35b32a5f2c5e173f9da333366f8f82cdd3225d545161eef9a09f787c1c78735a790cd31ff7a917c84ef71ccbe6f906035cd6bfe7f8788ececec52a7bde4f4978898a867ade5f2a55fcf18b7e9d67b904b17bbfb01ae99f0094629d3e577237597ef086816f5ae3efe4d4a62f9d583d5605eb3b3cdf25a90774b940d5837bfe4f4463660b5720dbd46ce78447c806b565f8c2a8d23952ae6fe38a75113a07e539621c7b7294c93c87fd466a54c1f30cd6be57f6da5797dc1697a44c61a6b27f51b5980eb73ca55f38d28d3e6d3cafc35a9af393d048d0b670ed5cfcf2f3d3d581b1ca6956be514be9aedac120eab795ebb4a6fbb015697dd701f9814239ef48e650b2f06f8a5cdf74bc30dff5ceb371fdbc2eafcf919afae7808a8bf4bcd04c7f9e009aef349092b0aa80ce312cecf2fc00e4960fabda0ab317b094865d3fe05effa19d92f5936f178949f7275ccfc743f1205f63c52ba3c336aa8539f0957316ee964e5781297849f4f7780351bb19ae5b551eb6d17019d60d3774e6f66fa05ac986ad105ec3256cdfc6e72822a9d464e07a205906a70f35ba34fecdbabd3a82b2512cd881d5554eb971e1061971d916df6b9d5d538b433353b3b42b6ed25a7efb6a72965e6797ae7f1c5f39f7bdbc9699718820493954f19b12bbe1b3dd8e96bd378aef376a4a50f430111d9d9d9e679ad2c150a92b32322eca6cc70727a2166fee0e6974c33bb2222230d3e21de7289094e0f064a272b221ec06ab05236ba7bc15bf45962f62a7ac0c103abbce0e3fb758834904ec362501a3f3d7810d2979d2d18ba6082f5cf43b225700cd92eb7e064faa6a962b7f11f09a68f73c9f47bf9674e53c7dd4f0bb64a7e99a9a301fba6cfd2370863bf9ac00a4e5f349d40b71e7530db4a5e0bf20c5aec04d976b7e1e965fdfbf355b1d366704f7dcf2c95fdd52f26c8c9e9251765b056ab858dc6028eddfb65a5ce7867c45bc05678407e81b03fdb4e73e8faf89b500b9d134c0207d3805a867745ac9057d3cfadb226f76411c8635d42a0abfe6a477a5a40ea96193f7ef3c20bcf7cbfe276ac323d23143b6d809f96a3601eeb1b14e397e5b2e20ddb507fdc162beecbbefd3deddacbd2d035c68e9cc1b777045b89ec1a1b8b58cd9e079c6ba4626f5936e80efac00d6bfaf675f3fbe26553766fdbb639353b2b2d784e10dec42332e491919110441e29a705d623d3139c9c1c62d233655b5f30b93b99ec9ca6cf9812afd246421256bc45640e7382b5915a71f8edefc1e687e5e9102e123e13e08321125fbc830a600532cbabaeb27468e0ae1b6aec3627bf06a1e6dd0bf68b9995e5ea9a29f6d3ce9ff92b0837cea58f7ebc3014c9322afc16617f2f58197b7bdc1b531978ccc6eebe7b66ab8bab1ffaa467c13111b08fed08867a5ac0c1713f80cd5e3f63442638c16a9ed7dc82b2427546d21402765a323e8b7c3b6ff5ebc42b788eef647c901ee7f25cb09a0da56677c8a864e3a69296fd5c5db6bef816b44b404e7532aedfacd81c3b2b9dbac131edfe9ea89dbc30623af41e740a5dc5cf04fe30c3e4b5d5e43ed0029d206560cb1ebbf0f07000ebf3fd7a8c34d93ef4c078873bd3a742e0dfad7089223f13c9998df264097ece6505dc8bd6cf9e3fa08c4f0d59f1cdb70cd8a9a4f8ee8d194ba7d965cde77e1592a70d1e1c379d1c4dd01c08a0edb3dbfa0d54eeac8e59b9d66b59c2f27beba8695638e211987fdfaacc33c833044b88d2ee6048c88f53695bd8e854a737574c8be8d30efbf343f02cc80c98dd591ea9552e924ddbba62c6336f4e5f0fdfc2defaddaf57acd87230f639f6d746ea991e25dbfa36013b790728b4ab62a77d0ffedffe8ab6b97e72d08e48166bb8d9f3c06f73f331b162915b2c412b4bbdbd74c637d389e7fabf7c3f6e9b6c719a5cc2fe8ec73e0ab1dfe2249248a5dd567274413bb472d573f7e1e972cbd6a54b976eddba7b8a2c3b40192ce7ff7c8bbf8429b3b77d4f7125844114bfc5d1e3d673e9c1d56179a4248a62bd65f6fb0024b6d05d354be4964df4f733c35d203d84b61ccc1eccd00ef70713e60f5daafb53c6fd85b4913047adf51367ba06dc0fbf1f1f90d597112c8f5ce938536deaacf60b9832ee07022b3446e22e098ec253f3e6f72f8e1b376e0676a2a94ee3e7c4102cd30e5f30fd8d2857efdc38a41547897686df479207ab32e323ec647676e1ae7de972f2d73c7ce55ce3ee4efe46e24efe68e6eeae71a77f96928465cab67d3f1d1bff76bcefca0980468b1d54b2eede8e6577a07bac025774c7bfb4119fb03ed98a97a6e2e179ac964b346aa5ddb615dbf0ab91cbc1692b66bc090a07158172fff0c24a9de96f6f0555e52961e2286f8a15ff2a26d7c2934fb07684bff2b27fa55467c4a76efd35745b6cfe5b8fd0d95ebe09cbe639fcec3b944c5dbfda228c5a9cbdfb47aa9c094ab56a71f8a03203be1489a3c253b73dbb1e9ea4030896086fa971e031f94d137a4193d44fec1d8bea78f2d2c0dcb9ec6b079ab9e40ffef4dd87b9733573d93ffb6be85b0a1a90ba6b95f7a3b78e7b61fa5473faee8d5f3fbe586d7cab8179874292be287adcb7c462f6eb50956b25d227274c583757a3cd804f8c1511e9e278c412ef73d738f098fefeaaaf2c32b8a77987c7236978ef62f068ae753143ee5af162d9e6ad2b7efd17b8b933b47efa0b3356ec3e189ea6b1e2a9cd74799c9c89a91e7340b56e79e863dfaeffd6c36b8246ae7cf5d51889d4f57e3c600df76ee2469f0b9819639c4b87e426581f9ed46999f17607776f5d0a17e5b87178696ebded123ba8d44aac9b8bb3b73d43c0fe6a79e4ca3bec014e9fbd4e12a975974a07089878c1162eb1ecdf36f2cbca35def72956f69d3629b3a3afa3e1fb684cc16853d866d99a463d208e1a8c0fc7af1f76d9e1f1ae7d6991ee52e69d36eacd44c4bd2638207a1c0568cfef361e73688b7d048d4b1237ac9ffd9b910ebe1f7887072031e8e80b7fdc5b74ec9b84299e522bafa949a58cf8094f8d041e42e0a92e522da1aff431af1eb2af0bf2481ee5f2f81b165d7ceac40952b40c2368ee7b97b38915707f362c6af5be4fb429290f84c294079e0f521ea4081f3cc0771e53525040499842779e9e0f9027553c12f242237d8991a8c91b92f82aa627b5f07c80d61096f1164274494cc4b66f2cc186ca3190e773048e9b0b9b588171e8f9a72c56e108afaa7a726f837af2df2df564159ed64cf12d4fbe8e3273d3036e3f6b0976077903554ce0dcbacbce97c0c36a60b07a722f3fb3af529bbe0fcd16fb781cf7a6b071b7cfda3bd41694a2ce8ab6c46aaf452f2d8193eac6ce97609ad7c18080c100f2ca34fbb237ef756f2323e43442a1f91be75466f912ba90f75239eb485edb7f7db625d6e92fa38d6470306070d06e09fb4c6092d7f84124e1be9f902cdfd6177b58629dba5c8aafd51338b14f3576d10e6b925706ebd0500e19e4802314089b9343ab94c1610f9441750e6a7041203974e40431dd97438738d0c10e39241a8ea2d847e2d041125013befc2b2b58774920088bb586e9b026790d70751d1c74150642a8c01c1cc782e5500ec3a018358c2a10010e817e8819f4921338440da935e5863849ce10f1cec13d638f8570f1742b587db5ad393952d7415757d7d8a7feb34a6f9957c00a68f70506b663b076a6cdd6c056acc386638270f4118e3b6a6f6787aeb4e320a376ea843c27264b2b615b5b9938ad44cd04445ef8f2642b582745829106e1b8da2d69aacab79a57a01c1cf21448463ec1bef83a020c6cbf8ea3a18ac968275c0303afc356dc5a5c8c0a3a860ac74f81516031193705071588bea0bbde4e0671b533a12815939151ed3951a19650d76fd780859cc049752b646e049679756d35e000333ac6acdd64c859bb81ab80c2603a0caddd842331188e3280ce6062ca38889fb6f2c9359802ea340227446005abc17b300b9514911130d91bd8d2c082341888cc4064a832182da9bf81a9185867c69b2ae8d1180cda493f58607da5af1534f0bd3f2b2bebf034ab791dcc426affd4e06f307c0a9be15303f2b0f91b8ce4ff2931a00a03a3f33750272c0c8c90e7f529e34ac759128686327cbacff51573a8776472707027685cf7f459edafae445bec6f9b0cc3f0a65583ff682958e660d65ba3d73c0ff20c82c6c54d5e6eed3e40b04615dff42703762fe3685c3a5eb704f8cb859771506ec9cd127f54de2cbc7cf3328eeff5bf0c9212ffcb974bfc6fe2305f74c391bc976f421d1d508c837a2f134d4921d8965c06211140654879f08ec95789a75f9580873a2b0ad11cde22b57a7f758dca8a8a8af22f29a183ae21a4e9e8eb9b374b888891f2953ce94dc6fb264f6cea011644415585d2a8e803bcebeaf1706d71c9cdc02842f1de19c2ffb2f6b9e54ad4fe6663b399b1d64d54d2641c7edd6465f87813af64249c3bab68e24682336bca2c97c743e9b72f8fc7a3e3b506d00f50ac77ef6a0d569f07b288bab0090887d937d185806c2ad940c5644f0a321e9f1072a021fa266349a4b0009e0d245e491319bc4fa3128f0d1b706b12a6dd77993469d7cc5d9364764a8d011bc82458c2bdfbdce1d2b2f29c95455eccba8c730760ec0fe9a402643201ba6da073077cb881ce31407671b4203b609a689dd936f02cd9590a38ee43c6132a06a9385ce6e222cb768d6c6fc2e90af6112851490b07848d5dd69e5fa3884109f5e7a671282f2750e236c4c5994fe340e763d8506e45416903b5f94fd369218c53466c60a396044ae19b8fd65de84fedd404ca6e91580e5dc0daf7822cf25656d389f27276528813644289f2f21371dc1c1a44c69464e20c32c30433fb0535669ca8194e8e4166a68803059d9a82db18f338d69e29c13c9d4c72b950e60777018bef5b98d74c062bb64aa6dac01939cacb2b707e8e0a3a21474505cef651c1d4cb993a5dc1182d18d81fa08a88a05e4126f9a8a02ec4895811a30f48a80a3241080982337e0c10280b21ad45e6df63695ea3fafa66f5f599cc6952f308e64ab1ca9fb0ed144cde085be897624cab595e89415c4d4d4d05bb215a28b146399410223b7a3035d486a954f0c4dcb433265e8c2fb5e1076085151561048a48cb4bab455e814e589fc9e6eb9a05e6a20535c3993e0459372658ff2ad2945799fe9ec5e5f5af4a7ccbad62c1029c2c08a1d0b9816a48856c8c1cd93335acf20c275f400fc06804e5191a8e44a1c5025ee41a4ecb8aa8444b5e5b13a57cdda56bf9adb5bc6612838a3367ce349e59403670861ac63883dc0290c1d6d8b880081b51d60875909d39c3989e21aed4897811712355d390e04863823795369ea1c6b40a312311c92cd15091e9efafc6bcf69137dc6a8e1d03732870c129aec8863594531989788c8a8e513bce9cb53fc6eac97a867566231da3b367514f9e9a4ae5048a68e8cf56ded726799d455e6e6b3c768c99568ca1525e8933899d61b5a50c639cc48cb32c2550fe0fe76c3aadd719cbc0a5a66ac42aeeb3fe1e3c9757c0ca4e89c64d9bc6cd93c6d58f196bbc39d69819d4d809d58cf626eedce46ca621b839dac8a1ab091451eb05db793d73f45ce9b9d2d27357603d47039cbb72140a14a2b4f40a585c614cce1d05ee282c57ae1c3d7a058d8fe27a1404e87e143dafa0e41ce520cad1a3505cb972ee287a63a07310f60a691477a82d65b08e94578cff67b241e3b016e1bc76e7c8ec7645c689eece31b22bc8d34a1132c8038ca2ff00ce687eee3fb820578c31fe8b0d5544559c7d519164a4bcf665883332324ad1a9a8880157c4d051b21de5558e1e6579ce88b5a1ee45acff51a33b95524bd6e06891c946d4ee00c5665e1129602d1a03e44ea0581fb741f2aa64b136173593d926714f563604cb5c206c7333ab6bbed04c2517d0fc02cff402c712db0b5c241298658b4c1b682e728fc9c888b199d718b43887935b565757375f00a6baf9df70b6cbe6e6ff052ccea789b369821827d62413755e68a61cf1696ea66a2cf32e2053d44cb5ff5644783af326997b1377641a4e362491a11667e1744728b6f24afb4051353761719e715a5276c2e2666ef264cba94b8d7396365bcc554add99298fb9094ef32c6742a5561ada076cf7d7551945ec1cac0d0d790dfc39591bcc39e3aec18a91a9232f56036f866b5e9d276e68980b4856d9ccab6a55866a55730312ceabbdb1814caa0d0bc2de88c5471b1b3e22ecc68d28ddb831ef23c23490ca470d1ce535088e005da4de1c7d4454ac7d03ced04dad71c5b9b869d1a059a582b4d9c82b0055a954d50883d90811b41b592969835362a5c1c28694142b3567f494a1874a8f816da081d726f27309149b7945cadbb8b1acac0c36badf4878c2303cbba30652321732356164c4f42c93572ae6d68dac350dbed1184c4cc231de5202c5665e911ace8203bbe18eeccf32f58d44033214884392f60bce725667d91d1151acac335b9c3dcb05dec8453ffb4488dbfe8b65c6f6ce325887cf6b067937f5a3e367cf7ef1df10f478d9f1b338d735145520831a0a61fd0245c0133402947ef145191a9efd02db3a4e964b0c56e4cf9e3d4e43618c3f90505f1c6783971dff6213353d4b621cff023ca4048a8dbcd21769cbaa48187404aeaaeaf81fe8f4dc55c05341d559045f759c62bd44d5e48868fbc7514fb517ab8e53dbaaaa3fd000b88005d4d0e30f109d09749136410caa526c6385bc92f73bcbaa4850968ecb380ed678590c57a5991398d8ca3c4db517879f7a1d6231c616a6809540b19557162b4b9e9b2e6294237b365f821a744e52bb18428e4574d11b6bde172f5e8c876a0c63bbdf2d861e2a0b20e422d266147a127613ce011fb2875827813c8406dacf04223402d64f39ac972e5501b64b97422836a0cd55979abd8f70e406dae3178d75487dbcb1762404d46cb22e55c55017901cdfcc04abf2dcc3da5e640cb94098e74b14eb808dbcd2f791cffeab334ed2dfd3e3668c1173e9524f120f8de8d2f14b7cac3d97843ced11d925b0a7587baa7a88e17e087849444e4473cfbf1a63091843d691b47da947485e36167d3a6c5ed3d2076039eedce38c58371b43ecefb9f4af3d4ba12f28044c3f103a3b9b60ede9d909c04402e6cc5e82e365b03af7847036442beae9a127618f60e77e14f3b13a43e3b0f50807fc0606826de415277b1b18a872a6444125c53b3bc76fc67a8c5b0cfe5704219187805446128f03aa00b973488810da7026b79f23d82081b0938b24ea71a6b98f678c882a0403d3407b9840848608141b79f5e363a5d910f5b0de08c45928930948bf15a040c0722cc5c842046c7efa39ac3df4d43b3b6f66f6f430f6cbb8c8c6c332c11a6623af04eac0256aed464fbe11abb370d31e6337eb679b241c012af2e69f4b5e5ee9d515433143077566bad79e4dcf53d761b0dacc6b70f04030c5dad34fba6392b373172cce5d5d3dfdaff26e0490cd2e267302c66293c9c565cc2b6a7722bb8976d798aeaefe1ef6a0f76f82d0cebdd4b48b0672c6ff6c9203bd35cc565e410be44c8cbb487c412fe1d17fd57e3e185038770938aecb14ea1119481800a824fd69e7f32497e43fc20470c72dea379a72e4dcd54aa0880a87cdeb00c5da65c46af47756903c080268120420aae738c8033912ef9055d40fb0f6f201102d39f39b48bde779017be8abd8403cac5d14abd6465ec3c86bdd0c567a0b5cd5cf7ad3bb7c7f17974d864b221604c7fee77bfabbf698e59510e9a94493c3050cd9c99e21a329abec6f25506ce595c1dadf0f2bbd0fecc921fe2021d51c36c10210d3747877751933d3df9f73c42caffd186d157bca93082010a13c89392fd47b7f0e51317945246a1b79c5b7d0e5911805889ed523de02996c53527f6f3fd3bbfa69c714d4f7b36c9240708a5e484716f5e6d0d321ebef67b012a8bdbd3bd98fdf5e10f4aabc058bfafbdb2fd248f5fd32e6b341f07a3feaa16827506ce4358cbc86ee5cd9db5fd95b798af77172a4bdf712bd1abc996e96d45f59d9bb885557d6332c7b7dcbfa7b6b29d6ca5e24e62c1dd9dfdb0bd17b498db9bc16819a4b3bf88131345f8c50dc6de495be86ded55b49a85ec1bbae2b2b052617fa4562c45ecd807ba7e97da09271d859c9103d46513df1e3454eaa4701eb2d63daae34102866e3e2f879a56308ba18f3de53dcb57a64139c28b6814d2c86defe45fb39ac310ceefdc46c536565ad09d67a72751d51d1c8c64789a4762251ed371ea311eb28f25acf3ad4b76f4a82b3ba67a7603eb68017aeb7dba25e01d0a65395f560a712817e27c9cdf3f8dcb25350ac42b51d74111932efd533d176d22432b5db8a8bfb8fecdf295a048dc05a5fdf2ed8898154f5a45e593f625ee9e089de7a4a18a2beb616985ac2e3d6db4f44b5ac9e6cff1b8a53f554485c6ad97d2d2b634e8a0cf953a7ea39aaace75325bb63b06a6ce4958e03e83d854d7f8cff75eee302e04e91f805202820ed80187728f818abc406cd4e7d5c4fcc29160c0172629196c4f4cdfa020c5b504f6d192aa00740ac0b4ed543bc8f4ff9132836f24a874cf416149c22ff78108210165c59114a11f6c794fff863ac1315b4c138b13bc0f531e16a99bbc3fe34aac01c307bf03ac52cac33dd0a1189d4565edd912a0bfe063a654bc95ce5534e8d3e5e218e0a90d8ca2b83b59673a9ad25155650cb2b2da8d68a4d2dae6df476f79e8961adb95f412ddfa91091a48c98d77a06246ce85e4b89455e4b0b464b36d684b1abe569887f811ddef9655450607430e2ada50b1b19f34aa08c90578d7bfd497edbb527e9c6094f9e640b464794274f9a399ce42a276bfbbd93427af9de9c25aa4d446c5325384bdd031b79959049ec0a488c93f927c9bf21853dacb5f9b87d965ffb19544f7e86013f431dd688d16727f34184c648e0ffd949629a8f87915f7f8afcd3d85a94d4323608319f04f8ec338c410e9804ff0c423791f11d82e1ff0e43e7b72ba0084ee633688d7432df28b3a6e3999c34b33235c7c3308d7ad22c3ec16aeb3ee0ce62fdfb53f9a8f33a46b0fe83e575d8fb001dbb043d9efcf7e47ce69ffce65f459e563b5819d688551ba8997abed18b2b8c5138a199a88d67cdc820e28991f24a47edd47674b47d0ea83a3a6e903857816bc3ed2a4176e32a48107c0783bf0d8f26bfa3038193fa55d480f84ff957af5e059bcf510ede37c881b7e577e47f0e11202c85866268f0ea0db0eab88a48c1fe04812218fe776d7762701260c17255afeff85cdfd6a6efc86febd07774e0ff28c705446dfa1b1d373a0047c7e7376e7c0ed8aeb6fde9861e1df49f77205dd55ffdbc0d7d6e74747cde81f21b50ea3bda906dfb1c2a1d37f41d575106b13fd7dfc05c5c8526f437f0ffb6035383486cdd5fe9f09b7c62aeb7202b2213698749b5a3c39a97f51856b435048a60f8df5f3546aca32465b4fe5151b4925f2358dd05a3caab35526cd3eb7314890c471b5018d5890aa0bf1dbba92b93d7077f6b5e13057a7d844204d9542cb6863544a954e63c4aacff83bc462b3af52122c53a8230223a3a1245ca68f6e42592c69411cdb2367da42c3a829c575974b33e325a760e2a39d1288b5e8c367a10e6400f225650953d8f58238dfd60c4bcceb58d55a950d6895c14b26b029f8e10d1b6444524605508444c9629d668c15d913e52e193a800180a11a8a3150245885ebf4e94b84db4add347a0d70914cd1ddb44708e124314027449144502d6752241f3a8f39a628ab5d308b393394d918a27137d9a15b2758a8836bde8bdce6885cfb90681a88eebaf4a40d65087e682447d67a2684da74011d1190227c227b10dd035cb1439390a51845e14d22c4aeeec9481165cd6b5c13520103474b28dd590618336f22ac50179296d9dfa4e200ee579283a71eb4c4c7411e9a3458b153932456262a228119ae9ec6cc302f4a4bf56472bfe0df808008e58b7e93b770ba0aad0df50081213050a658e22422658eaf34bc562e8f5bfefec84531fad68067f38d0f66bbfc766b1f51a1c0f6833af64a85ac7f96b9de73bcf9ffffdef3b29fd1eab9dbaf3e7a345c94b3b172b4204b5d18a68a058c00aaa68c5b57f3f7fed7c62f4efaf5d830ad8825a2948bc762d311ab489759d4ac5f9f38a4474c9e9148424ee8e154588daa04b75ea002bba5c03bd40e4d3d979fedf81bf764ddf48a008866ce49560bda643ead4e9ceebaec1d6791e3860ce4393a2585db542b14da754c482e21a823a7f2d5100b6d77489d1e7c11a809fef4c14549f03ac001f7027eac05c972b48c4389ddd07058ac8668528e47cbb22e47c778422028f150e52112d53c8b0210872fe3cc16a2baf0fc840323d5a136276465228727470652cc622647762a4ce47244a4e542cd2a332315a47b0020b978c48243a5d87f019acbac590589fddd774910ac1673a1fc5abe775bb218648d04d5d748a689046628a904a09141b794d61b10e47b1329dae7b3160ea6e902526ee8eac8b886808f159cc2895582a41ab03a1724e3415296375ba76e0eb9421893ec0eba217011f9d871e8989b206c64517add4e545c7b22d11ac0f4693d787a1ba3add4f40fff3bcfebfa311f32a1c6358876c7cdf7af00f94d7a17fa0bc0affffcbebc35df8753f4d5e875a91f4e6e1eb2c796e57a7337275aca6cecca58e91726a5bb73fb2d5952292211b796da558ebea4ed7c1f6491d69850600fa84944487a2d33a14511529b1a94f80fd8440c3f513608979dd27444bc341c184d651ff4f18156b721a76e708141bbf0fd0bc9eef3efd1578e4e69e3e4d1aeac6f67209fcd375dd0051d78d8073a18d2fbb01ce696ca49b34d17d1aecbabbc90111dfd35f42e52bf0064577dd27dd98008c4a2a68f3551db187883a14ea4e77e3e1747f796ec4bcfe1107ad9e078cdd7564cd056cd0506e2e46ff129b818640d25df725349e5b8715d0e6220f07d79d4bb1a219d8e4021234ebc64058424cd8e576331560312360070d9efe121b4347909c3e7d14a0145f175c1fbebf1a0c863f16eba0518c984ba89b20e108591a3097b7417b703cc40c0fed3441dddd4dddbb738d21a8c61839970dc50b4fdc8a70f8ec755b7925036c75b963800856838ddf5d72c618565b79bdfe0f9457da07cac7048d94d73f1ac6180dfbfec0f5246de1d8a2f2a461f3eab3658c61b55bd264156b7e59a19f77c698829ab133c46a5e5bf2ab9ad45bbc6586b102342cece012917b619935ac3857a52a5be0bdc4edef4f49494b92967827bda7328e3b37c1aaeb2a1dd266640dba4c1b2314e02a1e4861a74930c59a5b50d6241d1067e214156380b2b2a294696afe485efeffddd177151934612ab1b26f2c90529ce1a71e6a74cecfb582b52537dfb9b449e82e0f1b180b14a655a7181aab0a78693562851e9bdf95d7d864681d1a136428ac29722ed0e75ac7daa2d3177455e51515958e012aca2b73aeccd7f1a1f2b06237d0e9f30b2ac70615e4eb01291faa0956cc2d3c8ee9c604e5025013a4e658c736fd13eb3fb1fe2361fdbf020c00fb2fcd7818137c530000000049454e44ae426082
__favicon__
000001000200101000000100080068050000260000001010000001002000680400008e050000280000001000000020000000010008000000000000000000000000000000000000010000000000000202da008686e2005252d600d2d2fa002a2ac600a2a2ea076a6ade075a5ad6002a2af6000202e6009292f2004a4ae6002a2ad600b2b2ee07eeeefe078282fa007a7af6001212de00aaaaea005252e6008e8eee003e3ece073a3ad607fafafe008e8ee2005656d600e6e6fa00a6a6f2007e7ede000202f607babaf6077e7efa001e1ed2005656e6000202e2008686e6004e4ede00dadaf6072a2ace07a6a6ea006262e6002a2afe000202ee009a9af2004e4ee2002a2ade07b2b2f607f6f6fe008a8afa007e7ef200aeaeea003e3ed2003a3ade00fefefe077e7ee2071a1ade005656ea000000000000000000000000000000000000000007000000070000000000000000000000000000000000000000000000000000000700000007000000000000000000000000000000000000000000000000000000070000000700000000000000000000000000000000000000000000000000000007000000070000000000000000000000000000000000000000000000000000000700000007000000000000000000000000000000000000000000000000000000070000000700000000000000000000000000000000000000000000000000000007000000070000000000000000000000000000000000000000000000000000000700000007000000000000000000000000000000000000000000000000000000070000000700000000000000000000000000000000000000000000000000000007000000070000000000000000000000000000000000000000000000000000000700000007000000000000000000000000000000000000000000000000000000070000000700000000000000000000000000000000000000000000000000000007000000070000000000000000000000000000000000000000000000000000000700000007000000000000000000000000000000000000000000000000000000070000000700000000000000000000000000000000000000000000000000000007000000070000000000000000000000000000000000000000000000000000000700000007000000000000000000000000000000000000000000000000000000070000000700000000000000000000000000000000000000000000000000000007000000070000000000000000000000000000000000000000000000000000000700000007000000000000000000000000000000000000000000000000000000070000000700000000000000000000000000000000000000000000000000000007000000070000000000000000000000000000000000000000000000000000000700000007000000000000000000000000000000000000000000000000000000070000000700000000000000000000000000000000000000000000000000000007000000070000000035353535353535353535353535353535353535353535353535353535183730353535353535353535353535350224133535353535353535353535171e2305323518370f17351a3108291f2b2b1735353519240b0a1b28222a1d2a382f353535353227320e0320002209222d353535353535353535352616242c340c353535353535353535351c150101331c353535353535353535351a1c0404162535353535353535353535353535351e2e35353535353535353535353535352f140e353535353535353535353535353506111035353535353535353535353535072421353535353535353535353535350d120d353535353535353535353535353535353535350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000028000000100000002000000001002000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8f8fe3ff1b1bdfff8b8bfaffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5151d4ff4c4cdcff5353e6fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffbfbfeffb8b8f5ff8686e6ffa3a3e8ffafafebffffffffff8f8fe3ff1b1bdfff8080f8fffbfbfeffffffffffe5e5fbff7f7ff2ff2a2af6ff2a2affff7f7ffaff9a9af2ff9898f0fff8f8feffffffffffffffffffffffffff5555d5ff4c4cdcff4b4be4ff9393f0ffa6a6f2ff6060e4ff0000e2ff0000efff0000f5ff0000efff5555eafff7f7feffffffffffffffffffffffffffffffffffafafebffa5a5e9ffafafebffefeffdffd2d2f9ff1e1ed2ff0000d8ff0000e2ff0000e6ff0000e2ff2a2adeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff2a2acdff3939d7ff4c4ce0ff4c4ce2ff3939ddff2a2ad4ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f7fddff3c3ccfff8787e3ff8787e4ff3c3cd3ff7f7fe0ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe5e5f8ff7f7fddff2a2ac7ff2929c7ff3838d4ffdadaf7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb9b9f5ffb0b0f4fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5f5feff8d8defffededfcffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6868ddff1111ddff7979f7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5858d6ff4c4cdcff5656e6ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffb2b2ecffa9a9eaffb2b2ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00003535000035350000353500003535000035350000353500003535000030350000353500003535000035350000133500003535000035350000171e00000470
