package Catalyst::Helper;

use strict;
use base 'Class::Accessor::Fast';
use File::Spec;
use File::Path;
use IO::File;
use FindBin;

=head1 NAME

Catalyst::Helper - Bootstrap a Catalyst application

=head1 SYNOPSIS

See L<Catalyst::Manual::Intro>

=head1 DESCRIPTION

Bootstrap a Catalyst application.

=head2 METHODS

=head3 mk_app

=cut

sub mk_app {
    my ( $self, $name ) = @_;
    return 0 if $name =~ /[^\w\:]/;
    $self->{name} = $name;
    $self->{dir}  = $name;
    $self->{dir} =~ s/\:\:/-/g;
    $self->_mk_dirs;
    $self->_mk_appclass;
    $self->_mk_makefile;
    $self->_mk_apptest;
    $self->_mk_server;
    $self->_mk_test;
    $self->_mk_create;
    return 1;
}

sub _mk_dirs {
    my $self = shift;
    mkpath $self->{dir} unless -d $self->{dir};
    $self->{bin} = File::Spec->catdir( $self->{dir}, 'bin' );
    mkpath $self->{bin};
    $self->{lib} = File::Spec->catdir( $self->{dir}, 'lib' );
    mkpath $self->{lib};
    $self->{root} = File::Spec->catdir( $self->{dir}, 'root' );
    mkpath $self->{root};
    $self->{t} = File::Spec->catdir( $self->{dir}, 't' );
    mkpath $self->{t};
    $self->{class} = File::Spec->catdir( split( /\:\:/, $self->{name} ) );
    $self->{mod} = File::Spec->catdir( $self->{lib}, $self->{class} );
    mkpath $self->{mod};
    $self->{m} = File::Spec->catdir( $self->{mod}, 'M' );
    mkpath $self->{m};
    $self->{v} = File::Spec->catdir( $self->{mod}, 'V' );
    mkpath $self->{v};
    $self->{c} = File::Spec->catdir( $self->{mod}, 'C' );
    mkpath $self->{c};
    $self->{base} = File::Spec->rel2abs( $self->{dir} );
}

sub _mk_appclass {
    my $self  = shift;
    my $mod   = $self->{mod};
    my $name  = $self->{name};
    my $base  = $self->{base};
    my $class = IO::File->new("> $mod.pm")
      or die qq/Couldn't open "$mod.pm", "$!"/;
    print $class <<"EOF";
package $name;

use strict;
use Catalyst qw/-Debug/;

our \$VERSION = '0.01';

$name->config(
    name => '$name',
    root => '$base/root',
);

$name->action(

    '!default' => sub {
        my ( \$self, \$c ) = \@_;
        \$c->res->output('Congratulations, $name is on Catalyst!');
    },

);

=head1 NAME

$name - A very nice application

=head1 SYNOPSIS

    Very simple to use

=head1 DESCRIPTION

Very nice application.

=head1 AUTHOR

Clever guy

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
EOF
}

sub _mk_makefile {
    my $self     = shift;
    my $name     = $self->{name};
    my $dir      = $self->{dir};
    my $class    = $self->{class};
    my $makefile = IO::File->new("> $dir/Makefile.PL")
      or die qq/Couldn't open "$dir\/Makefile.PL", "$!"/;
    print $makefile <<"EOF";
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => '$name',
    VERSION_FROM => 'lib/$class.pm',
    PREREQ_PM    => { Catalyst => 0 }
);
EOF
}

sub _mk_apptest {
    my $self = shift;
    my $t    = $self->{t};
    my $name = $self->{name};
    my $test = IO::File->new("> $t/01app.t")
      or die qq/Couldn't open "$t\/01app.t", "$!"/;
    print $test <<"EOF";
use Test::More tests => 2;
use_ok( Catalyst::Test, '$name' );

ok( request('/')->is_success );
EOF
}

sub _mk_server {
    my $self   = shift;
    my $name   = $self->{name};
    my $bin    = $self->{bin};
    my $server = IO::File->new("> $bin/server")
      or die qq/Could't open "$bin\/server", "$!"/;
    print $server <<"EOF";
#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Pod::Usage;
use FindBin;
use lib "\$FindBin::Bin/../lib";
use Catalyst::Test '$name';

my \$help = 0;
my \$port = 3000;

GetOptions( 'help|?' => \\\$help, 'port=s' => \\\$port );

pod2usage(1) if \$help;

Catalyst::Test::server(\$port);

1;
__END__

=head1 NAME

server - Catalyst Testserver

=head1 SYNOPSIS

server [options]

 Options:
   -help    display this help and exits
   -port    port (defaults to 3000)

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst Testserver for this application.

=head1 AUTHOR

Sebastian Riedel, C<sri\@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software. You can redistribute it and/or modify it under
the same terms as perl itself.

=cut
EOF
    chmod 0700, "$bin/server";
}

sub _mk_test {
    my $self = shift;
    my $name = $self->{name};
    my $bin  = $self->{bin};
    my $test = IO::File->new("> $bin/test")
      or die qq/Could't open "$bin\/test", "$!"/;
    print $test <<"EOF";
#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Pod::Usage;
use FindBin;
use lib "\$FindBin::Bin/../lib";

my \$help = 0;

GetOptions( 'help|?' => \\\$help );

pod2usage(1) if ( \$help || !\$ARGV[0] );

require Catalyst::Test;
import Catalyst::Test '$name';

print get(\$ARGV[0]) . "\n";

1;
__END__

=head1 NAME

test - Catalyst Test

=head1 SYNOPSIS

test [options] uri

 Options:
   -help    display this help and exits

 Examples:
   perl test http://localhost/some_action
   perl test /some_action

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst action from the comand line.

=head1 AUTHOR

Sebastian Riedel, C<sri\@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software. You can redistribute it and/or modify it under
the same terms as perl itself.

=cut
EOF
    chmod 0700, "$bin/test";
}

sub _mk_create {
    my $self   = shift;
    my $name   = $self->{name};
    my $bin    = $self->{bin};
    my $create = IO::File->new("> $bin/create")
      or die qq/Could't open "$bin\/create", "$!"/;
    print $create <<"EOF";
#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Pod::Usage;
use Catalyst::Helper;

my \$help = 0;

GetOptions( 'help|?' => \$help );

pod2usage(1) if ( \$help || !\$ARGV[1] );

my \$helper = Catalyst::Helper->new;
pod2usage(1) unless \$helper->mk_component( '$name', \@ARGV );

1;
__END__

=head1 NAME

create - Create a new Catalyst Component

=head1 SYNOPSIS

create [options] model|view|controller name [helper] [options]

 Options:
   -help    display this help and exits

 Examples:
   perl create controller My::Controller
   perl create view My::View
   perl create view MyView TT
   perl create view TT TT
   perl create model My::Model
   perl create model SomeDB CDBI dbi:SQLite:/tmp/my.db
   perl create model AnotherDB CDBI dbi:Pg:dbname=foo root 4321

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Create a new Catalyst Component.

=head1 AUTHOR

Sebastian Riedel, C<sri\@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software. You can redistribute it and/or modify it under
the same terms as perl itself.

=cut
EOF
    chmod 0700, "$bin/create";
}

=head3 mk_component

=cut

sub mk_component {
    my ( $self, $app, $type, $name, $helper, @args ) = @_;
    return 0
      if ( $name =~ /[^\w\:]/ || !\$type =~ /^model|m|view|v|controller|c\$/i );
    return 0 if $name =~ /[^\w\:]/;
    $type = 'M' if $type =~ /model|m/i;
    $type = 'V' if $type =~ /view|v/i;
    $type = 'C' if $type =~ /controller|c/i;
    $self->{type}  = $type;
    $self->{name}  = $name;
    $self->{class} = "$app\::$type\::$name";
    $self->{app}   = $app;

    # Class
    my $appdir = File::Spec->catdir( split /\:\:/, $app );
    my $path = File::Spec->catdir( $FindBin::Bin, '..', 'lib', $appdir, $type );
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
    my $dir = File::Spec->catdir( $FindBin::Bin, '..', 't' );
    my $num = '01';
    for my $i (<$dir/*.t>) {
        $i =~ /(\d+)[^\/]*.t$/;
        my $j = $1 || $num;
        $num = $j if $j > $num;
    }
    $num++;
    $num = sprintf '%02d', $num;
    my $prefix = $name;
    $prefix =~ s/::/_/g;
    $prefix = lc $prefix;
    my $tname = lc( $num . $type . '_' . $prefix . '.t' );
    $self->{prefix}   = $prefix;
    $self->{test_dir} = $dir;
    $self->{test}     = "$dir/$tname";

    # Helper
    if ($helper) {
        my $comp = 'Model';
        $comp = 'View'       if $type eq 'V';
        $comp = 'Controller' if $type eq 'C';
        my $class = "Catalyst::Helper::$comp\::$helper";
        eval "require $class";
        die qq/Couldn't load helper "$class", "$@"/ if $@;
        if ( $class->can('mk_compclass') ) {
            $class->mk_compclass( $self, @args );
        }
        else { $self->_mk_compclass }

        if ( $class->can('mk_comptest') ) {
            $class->mk_comptest( $self, @args );
        }
        else { $self->_mk_comptest }
    }

    # Fallback
    else {
        $self->_mk_compclass;
        $self->_mk_comptest;
    }
    return 1;
}

sub _mk_compclass {
    my $self   = shift;
    my $app    = $self->{app};
    my $class  = $self->{class};
    my $type   = $self->{type};
    my $action = '';
    $action = <<"EOF" if $type eq 'C';

$app->action(

    '!?default' => sub {
        my ( \$self, \$c ) = \@_;
        \$c->res->output('Congratulations, $class is on Catalyst!');
    },

);
EOF
    my $file = $self->{file};
    my $comp = IO::File->new("> $file")
      or die qq/Couldn't open "$file", "$!"/;
    print $comp <<"EOF";
package $class;

use strict;
use base 'Catalyst::Base';
$action
=head1 NAME

$class - A Component

=head1 SYNOPSIS

    Very simple to use

=head1 DESCRIPTION

Very nice component.

=head1 AUTHOR

Clever guy

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
EOF
}

sub _mk_comptest {
    my $self   = shift;
    my $prefix = $self->{prefix};
    my $type   = $self->{type};
    my $class  = $self->{class};
    my $app    = $self->{app};
    my $test   = $self->{test};
    my $t = IO::File->new("> $test") or die qq/Couldn't open "$test", "$!"/;

    if ( $self->{type} eq 'C' ) {
        print $t <<"EOF";
use Test::More tests => 3;
use_ok( Catalyst::Test, '$app' );
use_ok('$class');

ok( request('$prefix')->is_success );
EOF
    }
    else {
        print $t <<"EOF";
use Test::More tests => 1;
use_ok('$class');
EOF
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

=head1 SEE ALSO

L<Catalyst::Manual>, L<Catalyst::Test>, L<Catalyst::Request>,
L<Catalyst::Response>, L<Catalyst>

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
