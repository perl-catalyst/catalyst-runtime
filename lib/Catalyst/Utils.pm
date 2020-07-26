package Catalyst::Utils;

use strict;
use File::Spec;
use HTTP::Request;
use Path::Class;
use URI;
use Carp qw/croak/;
use Cwd;
use Class::Load 'is_class_loaded';
use String::RewritePrefix;
use Class::Load ();
use namespace::clean;
use Devel::InnerPackage;
use Moose::Util;

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

        eval { $tmpdir->mkpath; 1 }
        or do {
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
a CPAN distribution which is not yet installed.

These are:

=over

=item Makefile.PL

=item Build.PL

=item dist.ini

=item L<cpanfile>

=back

=cut

sub dist_indicator_file_list {
    qw{Makefile.PL Build.PL dist.ini cpanfile};
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

            # return if it's a valid directory
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
        && is_class_loaded($class); # if a symbol entry exists we don't load again

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
        unless is_class_loaded($class);

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

Calling C<term_width> with a true value will cause it to be recalculated; you
can use this to cause it to get recalculated when your terminal is resized like
this

 $SIG{WINCH} = sub { Catalyst::Utils::term_width(1) };

=cut

my $_term_width;
my $_use_term_size_any;

sub term_width {
    my $force_reset = shift;

    undef $_term_width if $force_reset;

    return $_term_width if $_term_width;

    if ($ENV{COLUMNS} && $ENV{COLUMNS} =~ /\A\d+\z/) {
        return $_term_width = $ENV{COLUMNS};
    }

    if (!-t STDOUT && !-t STDERR) {
        return $_term_width = 80;
    }

    if (!defined $_use_term_size_any) {
        eval {
            require Term::Size::Any;
            Term::Size::Any->import();
            $_use_term_size_any = 1;
            1;
        } or do {
            if ( $@ =~ m[Can't locate Term/Size/Any\.pm] ) {
                warn "Term::Size::Any is not installed, can't autodetect terminal column width\n";
            }
            else {
                warn "There was an error trying to detect your terminal size: $@\n";
            }
            $_use_term_size_any = 0;
        };
    }

    my $width;

    if ($_use_term_size_any) {
        $width = Term::Size::Any::chars(*STDERR) || Term::Size::Any::chars(*STDOUT);
    }

    if (!$width || $width < 80) {
        $width = 80;
    }

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

=head2 build_middleware (@args)

Internal application that converts a single middleware definition (see
L<Catalyst/psgi_middleware>) into an actual instance of middleware.

=cut

sub build_middleware {
    my ($class, $namespace, @init_args) = @_;

    if(
      $namespace =~s/^\+// ||
      $namespace =~/^Plack::Middleware/ ||
      $namespace =~/^$class/
    ) {  ## the string is a full namespace
        return Class::Load::try_load_class($namespace) ?
          $namespace->new(@init_args) :
            die "Can't load class $namespace";
    } else { ## the string is a partial namespace
      if(Class::Load::try_load_class($class .'::Middleware::'. $namespace)) { ## Load Middleware from Project namespace
          my $ns = $class .'::Middleware::'. $namespace;
          return $ns->new(@init_args);
        } elsif(Class::Load::try_load_class("Plack::Middleware::$namespace")) { ## Act like Plack::Builder
          return "Plack::Middleware::$namespace"->new(@init_args);
        } else {
          die "Can't load middleware via '$namespace'.  It's not ".$class."::Middleware::".$namespace." or Plack::Middleware::$namespace";
        }
    }

    return; ## be sure we can count on a proper return when valid
}

=head2 apply_registered_middleware ($psgi)

Given a $psgi reference, wrap all the L<Catalyst/registered_middlewares>
around it and return the wrapped version.

This exists to deal with the fact Catalyst registered middleware can be
either an object with a wrap method or a coderef.

=cut

sub apply_registered_middleware {
    my ($class, $psgi) = @_;
    my $new_psgi = $psgi;
    foreach my $middleware ($class->registered_middlewares) {
        $new_psgi = Scalar::Util::blessed $middleware ?
          $middleware->wrap($new_psgi) :
            $middleware->($new_psgi);
    }
    return $new_psgi;
}

=head2 inject_component

Used to add components at runtime:

    into        The Catalyst package to inject into (e.g. My::App)
    component   The component package to inject
    traits      (Optional) ArrayRef of L<Moose::Role>s that the component should consume.
    as          An optional moniker to use as the package name for the derived component

For example:

    Catalyst::Utils::inject_component( into => My::App, component => Other::App::Controller::Apple )

        The above will create 'My::App::Controller::Other::App::Controller::Apple'

    Catalyst::Utils::inject_component( into => My::App, component => Other::App::Controller::Apple, as => Apple )

        The above will create 'My::App::Controller::Apple'

    Catalyst::Utils::inject_component( into => $myapp, component => 'MyRootV', as => 'Controller::Root' );

Will inject Controller, Model, and View components into your Catalyst application
at setup (run)time. It does this by creating a new package on-the-fly, having that
package extend the given component, and then having Catalyst setup the new component
(via $app->setup_component).

B<NOTE:> This is basically a core version of L<CatalystX::InjectComponent>.  If you were using that
you can now use this safely instead.  Going forward changes required to make this work will be
synchronized with the core method.

B<NOTE:> The 'traits' option is unique to the L<Catalyst::Utils> version of this feature.

B<NOTE:> These injected components really need to be a L<Catalyst::Component> and a L<Moose>
based class.

=cut

sub inject_component {
    my %given = @_;
    my ($into, $component, $as) = @given{qw/into component as/};

    croak "No Catalyst (package) given" unless $into;
    croak "No component (package) given" unless $component;

    Class::Load::load_class($component);

    $as ||= $component;
    unless ( $as =~ m/^(?:Controller|Model|View)::/ || $given{skip_mvc_renaming} ) {
        my $category;
        for (qw/ Controller Model View /) {
            if ( $component->isa( "Catalyst::$_" ) ) {
                $category = $_;
                last;
            }
        }
        croak "Don't know what kind of component \"$component\" is" unless $category;
        $as = "${category}::$as";
    }
    my $component_package = join '::', $into, $as;

    unless ( Class::Load::is_class_loaded $component_package ) {
        eval "package $component_package; use base qw/$component/; 1;" or
            croak "Unable to build component package for \"$component_package\": $@";
        Moose::Util::apply_all_roles($component_package, @{$given{traits}}) if $given{traits};
        (my $file = "$component_package.pm") =~ s{::}{/}g;
        $INC{$file} ||= 1;
    }

    my $_setup_component = sub {
      my $into = shift;
      my $component_package = shift;
      $into->components->{$component_package} = $into->delayed_setup_component( $component_package );
    };

    $_setup_component->( $into, $component_package );
}

=head1 PSGI Helpers

Utility functions to make it easier to work with PSGI applications under Catalyst

=head2 env_at_path_prefix

Localize C<$env> under the current controller path prefix:

    package MyApp::Controller::User;

    use Catalyst::Utils;

    use base 'Catalyst::Controller';

    sub name :Local {
      my ($self, $c) = @_;
      my $env = $c->Catalyst::Utils::env_at_path_prefix;
    }

Assuming you have a request like GET /user/name:

In the example case C<$env> will have PATH_INFO of '/name' instead of
'/user/name' and SCRIPT_NAME will now be '/user'.

=cut

sub env_at_path_prefix {
  my $ctx = shift;
  my $path_prefix = $ctx->controller->path_prefix;
  my $env = $ctx->request->env;
  my $path_info = $env->{PATH_INFO};
  my $script_name = ($env->{SCRIPT_NAME} || '');

  $path_info =~ s/(^\/\Q$path_prefix\E)//;
  $script_name = "$script_name$1";

  return +{
    %$env,
    PATH_INFO => $path_info,
    SCRIPT_NAME => $script_name };
}

=head2 env_at_action

Localize C<$env> under the current action namespace.

    package MyApp::Controller::User;

    use Catalyst::Utils;

    use base 'Catalyst::Controller';

    sub name :Local {
      my ($self, $c) = @_;
      my $env = $c->Catalyst::Utils::env_at_action;
    }

Assuming you have a request like GET /user/name:

In the example case C<$env> will have PATH_INFO of '/' instead of
'/user/name' and SCRIPT_NAME will now be '/user/name'.

Alternatively, assuming you have a request like GET /user/name/foo:

In this example case C<$env> will have PATH_INFO of '/foo' instead of
'/user/name/foo' and SCRIPT_NAME will now be '/user/name'.

This is probably a common case where you want to mount a PSGI application
under an action but let the Args fall through to the PSGI app.

=cut

sub env_at_action {
  my $ctx = shift;
  my $argpath = join '/', @{$ctx->request->arguments};
  my $path = '/' . $ctx->request->path;

  $path =~ s/\/?\Q$argpath\E\/?$//;

  my $env = $ctx->request->env;
  my $path_info = $env->{PATH_INFO};
  my $script_name = ($env->{SCRIPT_NAME} || '');

  $path_info =~ s/(^\Q$path\E)//;
  $script_name = "$script_name$1";

  return +{
    %$env,
    PATH_INFO => $path_info,
    SCRIPT_NAME => $script_name };
}

=head2 env_at_request_uri

Localize C<$env> under the current request URI:

    package MyApp::Controller::User;

    use Catalyst::Utils;

    use base 'Catalyst::Controller';

    sub name :Local Args(1) {
      my ($self, $c, $id) = @_;
      my $env = $c->Catalyst::Utils::env_at_request_uri
    }

Assuming you have a request like GET /user/name/hello:

In the example case C<$env> will have PATH_INFO of '/' instead of
'/user/name' and SCRIPT_NAME will now be '/user/name/hello'.

=cut

sub env_at_request_uri {
  my $ctx = shift;
  my $path = '/' . $ctx->request->path;
  my $env = $ctx->request->env;
  my $path_info = $env->{PATH_INFO};
  my $script_name = ($env->{SCRIPT_NAME} || '');

  $path_info =~ s/(^\Q$path\E)//;
  $script_name = "$script_name$1";

  return +{
    %$env,
    PATH_INFO => $path_info,
    SCRIPT_NAME => $script_name };
}

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
