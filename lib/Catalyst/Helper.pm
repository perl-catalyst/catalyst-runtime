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
    $self->_mk_readme;
    $self->_mk_changes;
    $self->_mk_apptest;
    $self->_mk_server;
    $self->_mk_test;
    $self->_mk_create;
    return 1;
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
    return 1;
}

=head3 mk_dir

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
    my $dir = $self->{test_dir};
    my $num = '01';
    for my $i (<$dir/*.t>) {
        $i =~ /(\d+)[^\/]*.t$/;
        my $j = $1 || $num;
        $num = $j if $j > $num;
    }
    $num++;
    $num = sprintf '%02d', $num;
    if ($tname) { $tname = "$num$tname.t" }
    else {
        my $name   = $self->{name};
        my $type   = $self->{type};
        my $prefix = $name;
        $prefix =~ s/::/_/g;
        $prefix         = lc $prefix;
        $tname          = lc( $num . $type . '_' . $prefix . '.t' );
        $self->{prefix} = $prefix;
    }
    return "$dir/$tname";
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
    my $name = $self->{name};
    my $base = $self->{base};
    $self->mk_file( "$mod.pm", <<"EOF");
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
    my $self  = shift;
    my $name  = $self->{name};
    my $dir   = $self->{dir};
    my $class = $self->{class};
    $self->mk_file( "$dir\/Makefile.PL", <<"EOF");
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => '$name',
    VERSION_FROM => 'lib/$class.pm',
    PREREQ_PM    => { Catalyst => 0 }
);
EOF
}

sub _mk_readme {
    my $self = shift;
    my $dir  = $self->{dir};
    $self->mk_file( "$dir\/README", <<"EOF");
Run script/server.pl to test the application.
EOF
}

sub _mk_changes {
    my $self = shift;
    my $name = $self->{name};
    my $dir  = $self->{dir};
    my $time = localtime time;
    $self->mk_file( "$dir\/Changes", <<"EOF");
This file documents the revision history for Perl extension $name.

0.01  $time
        - initial revision, generated by Catalyst
EOF
}

sub _mk_apptest {
    my $self = shift;
    my $t    = $self->{t};
    my $name = $self->{name};
    $self->mk_file( "$t\/01app.t", <<"EOF");
use Test::More tests => 2;
use_ok( Catalyst::Test, '$name' );

ok( request('/')->is_success );
EOF
    $self->mk_file( "$t\/02podcoverage.t", <<"EOF");
use Test::More;

eval "use Test::Pod::Coverage 1.04";
plan skip_all => 'Test::Pod::Coverage 1.04 required' if \$@;
plan skip_all => 'set TEST_POD to enable this test' unless \$ENV{TEST_POD};

all_pod_coverage_ok();
EOF
}

sub _mk_server {
    my $self   = shift;
    my $name   = $self->{name};
    my $script = $self->{script};
    $self->mk_file( "$script\/server.pl", <<"EOF");
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

Sebastian Riedel, C<sri\@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software. You can redistribute it and/or modify it under
the same terms as perl itself.

=cut
EOF
    chmod 0700, "$script/server.pl";
}

sub _mk_test {
    my $self   = shift;
    my $name   = $self->{name};
    my $script = $self->{script};
    $self->mk_file( "$script/test.pl", <<"EOF");
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

Sebastian Riedel, C<sri\@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software. You can redistribute it and/or modify it under
the same terms as perl itself.

=cut
EOF
    chmod 0700, "$script/test.pl";
}

sub _mk_create {
    my $self   = shift;
    my $name   = $self->{name};
    my $script = $self->{script};
    $self->mk_file( "$script\/create.pl", <<"EOF");
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
    chmod 0700, "$script/create.pl";
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
    return $self->mk_file( "$file", <<"EOF");
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
    if ( $self->{type} eq 'C' ) {
        $self->mk_file( "$test", <<"EOF");
use Test::More tests => 3;
use_ok( Catalyst::Test, '$app' );
use_ok('$class');

ok( request('$prefix')->is_success );
EOF
    }
    else {
        $self->mk_file( "$test", <<"EOF");
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
