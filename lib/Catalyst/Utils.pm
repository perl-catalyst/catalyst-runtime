package Catalyst::Utils;

use strict;
use File::Spec;
use HTTP::Request;
use Path::Class;
use URI;
use Carp qw/croak/;
use Cwd;
use Class::MOP;
use String::RewritePrefix;

use namespace::clean;

=head1 NAME

Catalyst::Utils - The Catalyst Utils

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

Catalyst Utilities.

=head1 METHODS

=head2 appprefix($class)

    MyApp::Foo becomes myapp_foo

=cut

sub appprefix {
    my $class = shift;
    $class =~ s/::/_/g;
    $class = lc($class);
    return $class;
}

=head2 class2appclass($class);

    MyApp::Controller::Foo::Bar becomes MyApp
    My::App::Controller::Foo::Bar becomes My::App

=cut

sub class2appclass {
    my $class = shift || '';
    my $appname = '';
    if ( $class =~ /^(.+?)::([MVC]|Model|View|Controller)::.+$/ ) {
        $appname = $1;
    }
    return $appname;
}

=head2 class2classprefix($class);

    MyApp::Controller::Foo::Bar becomes MyApp::Controller
    My::App::Controller::Foo::Bar becomes My::App::Controller

=cut

sub class2classprefix {
    my $class = shift || '';
    my $prefix;
    if ( $class =~ /^(.+?::([MVC]|Model|View|Controller))::.+$/ ) {
        $prefix = $1;
    }
    return $prefix;
}

=head2 class2classsuffix($class);

    MyApp::Controller::Foo::Bar becomes Controller::Foo::Bar

=cut

sub class2classsuffix {
    my $class = shift || '';
    my $prefix = class2appclass($class) || '';
    $class =~ s/$prefix\:://;
    return $class;
}

=head2 class2env($class);

Returns the environment name for class.

    MyApp becomes MYAPP
    My::App becomes MY_APP

=cut

sub class2env {
    my $class = shift || '';
    $class =~ s/::/_/g;
    return uc($class);
}

=head2 class2prefix( $class, $case );

Returns the uri prefix for a class. If case is false the prefix is converted to lowercase.

    My::App::Controller::Foo::Bar becomes foo/bar

=cut

sub class2prefix {
    my $class = shift || '';
    my $case  = shift || 0;
    my $prefix;
    if ( $class =~ /^.+?::([MVC]|Model|View|Controller)::(.+)$/ ) {
        $prefix = $case ? $2 : lc $2;
        $prefix =~ s{::}{/}g;
    }
    return $prefix;
}

=head2 class2tempdir( $class [, $create ] );

Returns a tempdir for a class. If create is true it will try to create the path.

    My::App becomes /tmp/my/app
    My::App::Controller::Foo::Bar becomes /tmp/my/app/c/foo/bar

=cut

sub class2tempdir {
    my $class  = shift || '';
    my $create = shift || 0;
    my @parts = split '::', lc $class;

    my $tmpdir = dir( File::Spec->tmpdir, @parts )->cleanup;

    if ( $create && !-e $tmpdir ) {

        eval { $tmpdir->mkpath };

        if ($@) {
            # don't load Catalyst::Exception as a BEGIN in Utils,
            # because Utils often gets loaded before MyApp.pm, and if
            # Catalyst::Exception is loaded before MyApp.pm, it does
            # not honor setting
            # $Catalyst::Exception::CATALYST_EXCEPTION_CLASS in
            # MyApp.pm
            require Catalyst::Exception;
            Catalyst::Exception->throw(
                message => qq/Couldn't create tmpdir '$tmpdir', "$@"/ );
        }
    }

    return $tmpdir->stringify;
}

=head2 home($class)

Returns home directory for given class.

=head2 dist_indicator_file_list

Returns a list of files which can be tested to check if you're inside
a checkout

=cut

sub dist_indicator_file_list {
    qw{Makefile.PL Build.PL dist.ini};
}

sub home {
    my $class = shift;

    # make an $INC{ $key } style string from the class name
    (my $file = "$class.pm") =~ s{::}{/}g;

    if ( my $inc_entry = $INC{$file} ) {
        {
            # look for an uninstalled Catalyst app

            # find the @INC entry in which $file was found
            (my $path = $inc_entry) =~ s/$file$//;
            $path ||= cwd() if !defined $path || !length $path;
            my $home = dir($path)->absolute->cleanup;

            # pop off /lib and /blib if they're there
            $home = $home->parent while $home =~ /b?lib$/;

            # only return the dir if it has a Makefile.PL or Build.PL or dist.ini
            if (grep { -f $home->file($_) } dist_indicator_file_list()) {
                # clean up relative path:
                # MyApp/script/.. -> MyApp

                my $dir;
                my @dir_list = $home->dir_list();
                while (($dir = pop(@dir_list)) && $dir eq '..') {
                    $home = dir($home)->parent->parent;
                }

                return $home->stringify;
            }
        }

        {
            # look for an installed Catalyst app

            # trim the .pm off the thing ( Foo/Bar.pm -> Foo/Bar/ )
            ( my $path = $inc_entry) =~ s/\.pm$//;
            my $home = dir($path)->absolute->cleanup;

            # return if if it's a valid directory
            return $home->stringify if -d $home;
        }
    }

    # we found nothing
    return 0;
}

=head2 prefix($class, $name);

Returns a prefixed action.

    MyApp::Controller::Foo::Bar, yada becomes foo/bar/yada

=cut

sub prefix {
    my ( $class, $name ) = @_;
    my $prefix = &class2prefix($class);
    $name = "$prefix/$name" if $prefix;
    return $name;
}

=head2 request($uri)

Returns an L<HTTP::Request> object for a uri.

=cut

sub request {
    my $request = shift;
    unless ( ref $request ) {
        if ( $request =~ m/^http/i ) {
            $request = URI->new($request);
        }
        else {
            $request = URI->new( 'http://localhost' . $request );
        }
    }
    unless ( ref $request eq 'HTTP::Request' ) {
        $request = HTTP::Request->new( 'GET', $request );
    }
    return $request;
}

=head2 ensure_class_loaded($class_name, \%opts)

Loads the class unless it already has been loaded.

If $opts{ignore_loaded} is true always tries the require whether the package
already exists or not. Only pass this if you're either (a) sure you know the
file exists on disk or (b) have code to catch the file not found exception
that will result if it doesn't.

=cut

sub ensure_class_loaded {
    my $class = shift;
    my $opts  = shift;

    croak "Malformed class Name $class"
        if $class =~ m/(?:\b\:\b|\:{3,})/;

    croak "Malformed class Name $class"
        if $class =~ m/[^\w:]/;

    croak "ensure_class_loaded should be given a classname, not a filename ($class)"
        if $class =~ m/\.pm$/;

    # $opts->{ignore_loaded} can be set to true, and this causes the class to be required, even
    # if it already has symbol table entries. This is to support things like Schema::Loader, which
    # part-generate classes in memory, but then also load some of their contents from disk.
    return if !$opts->{ ignore_loaded }
        && Class::MOP::is_class_loaded($class); # if a symbol entry exists we don't load again

    # this hack is so we don't overwrite $@ if the load did not generate an error
    my $error;
    {
        local $@;
        my $file = $class . '.pm';
        $file =~ s{::}{/}g;
        eval { CORE::require($file) };
        $error = $@;
    }

    die $error if $error;

    warn "require $class was successful but the package is not defined."
        unless Class::MOP::is_class_loaded($class);

    return 1;
}

=head2 merge_hashes($hashref, $hashref)

Base code to recursively merge two hashes together with right-hand precedence.

=cut

sub merge_hashes {
    my ( $lefthash, $righthash ) = @_;

    return $lefthash unless defined $righthash;

    my %merged = %$lefthash;
    for my $key ( keys %$righthash ) {
        my $right_ref = ( ref $righthash->{ $key } || '' ) eq 'HASH';
        my $left_ref  = ( ( exists $lefthash->{ $key } && ref $lefthash->{ $key } ) || '' ) eq 'HASH';
        if( $right_ref and $left_ref ) {
            $merged{ $key } = merge_hashes(
                $lefthash->{ $key }, $righthash->{ $key }
            );
        }
        else {
            $merged{ $key } = $righthash->{ $key };
        }
    }

    return \%merged;
}

=head2 env_value($class, $key)

Checks for and returns an environment value. For instance, if $key is
'home', then this method will check for and return the first value it finds,
looking at $ENV{MYAPP_HOME} and $ENV{CATALYST_HOME}.

=cut

sub env_value {
    my ( $class, $key ) = @_;

    $key = uc($key);
    my @prefixes = ( class2env($class), 'CATALYST' );

    for my $prefix (@prefixes) {
        if ( defined( my $value = $ENV{"${prefix}_${key}"} ) ) {
            return $value;
        }
    }

    return;
}

=head2 term_width

Try to guess terminal width to use with formatting of debug output

All you need to get this work, is:

1) Install Term::Size::Any, or

2) Export $COLUMNS from your shell.

(Warning to bash users: 'echo $COLUMNS' may be showing you the bash
variable, not $ENV{COLUMNS}. 'export COLUMNS=$COLUMNS' and you should see
that 'env' now lists COLUMNS.)

As last resort, default value of 80 chars will be used.

=cut

my $_term_width;

sub term_width {
    return $_term_width if $_term_width;

    my $width = eval '
        use Term::Size::Any;
        my ($columns, $rows) = Term::Size::Any::chars;
        return $columns;
    ';

    if ($@) {
        $width = $ENV{COLUMNS}
            if exists($ENV{COLUMNS})
            && $ENV{COLUMNS} =~ m/^\d+$/;
    }

    $width = 80 unless ($width && $width >= 80);
    return $_term_width = $width;
}


=head2 resolve_namespace

Method which adds the namespace for plugins and actions.

  __PACKAGE__->setup(qw(MyPlugin));

  # will load Catalyst::Plugin::MyPlugin

=cut


sub resolve_namespace {
    my $appnamespace = shift;
    my $namespace = shift;
    my @classes = @_;
    return String::RewritePrefix->rewrite({
        q[]  => qq[${namespace}::],
        q[+] => q[],
        (defined $appnamespace
            ? (q[~] => qq[${appnamespace}::])
            : ()
        ),
    }, @classes);
}


=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
