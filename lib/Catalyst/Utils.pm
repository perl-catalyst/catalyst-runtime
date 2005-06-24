package Catalyst::Utils;

use strict;
use attributes ();
use Catalyst::Exception;
use File::Spec;
use HTTP::Request;
use Path::Class;
use URI;

=head1 NAME

Catalyst::Utils - The Catalyst Utils

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item attrs($coderef)

Returns attributes for coderef in a arrayref

=cut

sub attrs { attributes::get( $_[0] ) || [] }

=item class2appclass($class);

Returns the appclass for class.

    MyApp::C::Foo::Bar becomes MyApp
    My::App::C::Foo::Bar becomes My::App

=cut

sub class2appclass {
    my $class = shift || '';
    my $appname = '';
    if ( $class =~ /^(.*)::([MVC]|Model|View|Controller)?::.*$/ ) {
        $appname = $1;
    }
    return $appname;
}

=item class2classprefix($class);

Returns the classprefix for class.

    MyApp::C::Foo::Bar becomes MyApp::C
    My::App::C::Foo::Bar becomes My::App::C

=cut

sub class2classprefix {
    my $class = shift || '';
    my $prefix;
    if ( $class =~ /^(.*::[MVC]|Model|View|Controller)?::.*$/ ) {
        $prefix = $1;
    }
    return $prefix;
}

=item class2classsuffix($class);

Returns the classsuffix for class.

    MyApp::C::Foo::Bar becomes C::Foo::Bar

=cut

sub class2classsuffix {
    my $class = shift || '';
    my $prefix = class2appclass($class) || '';
    $class =~ s/$prefix\:\://;
    return $class;
}

=item class2env($class);

Returns the enviroment name for class.

    MyApp becomes MYAPP
    My::App becomes MY_APP

=cut

sub class2env {
    my $class = shift || '';
    $class =~ s/\:\:/_/g;
    return uc($class);
}

=item class2prefix( $class, $case );

Returns the prefix for class.

    My::App::C::Foo::Bar becomes /foo/bar

=cut

sub class2prefix {
    my $class = shift || '';
    my $case  = shift || 0;
    my $prefix;
    if ( $class =~ /^.*::([MVC]|Model|View|Controller)?::(.*)$/ ) {
        $prefix = $case ? $2 : lc $2;
        $prefix =~ s/\:\:/\//g;
    }
    return $prefix;
}

=item class2tempdir( $class [, $create ] );

Returns a tempdir for class. If create is true it will try to create the path.

    My::App becomes /tmp/my/app
    My::App::C::Foo::Bar becomes /tmp/my/app/c/foo/bar

=cut

sub class2tempdir {
    my $class  = shift || '';
    my $create = shift || 0;
    my @parts  = split '::', lc $class;

    my $tmpdir = dir( File::Spec->tmpdir, @parts )->cleanup;

    if ( $create && ! -e $tmpdir ) {

        eval { $tmpdir->mkpath };

        if ( $@ ) {
            Catalyst::Exception->throw(
                message => qq/Couldn't create tmpdir '$tmpdir', "$@"/
            );
        }
    }

    return $tmpdir->stringify;
}

=item home($class)

Returns home directory for given class.

=cut

sub home {
    my $name = shift;
    $name =~ s/\:\:/\//g;
    my $home = 0;
    if ( my $path = $INC{"$name.pm"} ) {
        $home = file($path)->absolute->dir;
        $name =~ /(\w+)$/;
        my $append = $1;
        my $subdir = dir($home)->subdir($append);
        for ( split '/', $name ) { $home = dir($home)->parent }
        if ( $home =~ /blib$/ ) { $home = dir($home)->parent }
        elsif (!-f file( $home, 'Makefile.PL' )
            && !-f file( $home, 'Build.PL' ) )
        {
            $home = $subdir;
        }
        # clean up relative path:
        # MyApp/script/.. -> MyApp
        my ($lastdir) = $home->dir_list( -1, 1 );
        if ( $lastdir eq '..' ) {
            $home = dir($home)->parent->parent;
        }
    }
    return $home;
}

=item prefix($class, $name);

Returns a prefixed action.

    MyApp::C::Foo::Bar, yada becomes /foo/bar/yada

=cut

sub prefix {
    my ( $class, $name ) = @_;
    my $prefix = &class2prefix($class);
    $name = "$prefix/$name" if $prefix;
    return $name;
}

=item reflect_actions($class);

Returns an arrayref containing all actions of a component class.

=cut

sub reflect_actions {
    my $class   = shift;
    my $actions = [];
    eval '$actions = $class->_action_cache';
    
    if ( $@ ) {
        Catalyst::Exception->throw(
            message => qq/Couldn't reflect actions of component "$class", "$@"/
        );
    }
    
    return $actions;
}

=item request($string);

Returns an C<HTTP::Request> from a string.

=cut

sub request {
    my $request = shift;

    unless ( ref $request ) {

        if ( $request =~ m/http/i ) {
            $request = URI->new($request)->canonical;
        }
        else {
            $request = URI->new( 'http://localhost' . $request )->canonical;
        }
    }

    unless ( ref $request eq 'HTTP::Request' ) {
        $request = HTTP::Request->new( 'GET', $request );
    }

    return $request;
}

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
