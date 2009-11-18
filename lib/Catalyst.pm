package Catalyst;

use Moose;
use Moose::Meta::Class ();
extends 'Catalyst::Component';
use Moose::Util qw/find_meta/;
use B::Hooks::EndOfScope ();
use Catalyst::Exception;
use Catalyst::Log;
use Catalyst::Utils;
use Catalyst::Controller;
use Catalyst::Context;
use Catalyst::Exception::Detach;
use Catalyst::Exception::Go;
use Devel::InnerPackage ();
use Module::Pluggable::Object ();
use Text::SimpleTable ();
use Path::Class::Dir ();
use Path::Class::File ();
use Tree::Simple::Visitor::FindByUID;
use Class::C3::Adopt::NEXT;
use attributes;
use utf8;
use Carp qw/croak carp shortmess/;

BEGIN { require 5.008004; }

sub comp { shift->component(@_) }

#I imagine that very few of these really need to be class variables. if any.
#maybe we should just make them attributes with a default?
__PACKAGE__->mk_classdata($_)
  for qw/components arguments dispatcher engine log dispatcher_class
  engine_class context_class request_class response_class stats_class
  setup_finished/;

__PACKAGE__->context_class('Catalyst::Context');
__PACKAGE__->dispatcher_class('Catalyst::Dispatcher');
__PACKAGE__->engine_class('Catalyst::Engine::CGI');
__PACKAGE__->request_class('Catalyst::Request');
__PACKAGE__->response_class('Catalyst::Response');
__PACKAGE__->stats_class('Catalyst::Stats');

# Remember to update this in Catalyst::Runtime as well!

our $VERSION = '5.80013';

{
    my $dev_version = $VERSION =~ /_\d{2}$/;
    *_IS_DEVELOPMENT_VERSION = sub () { $dev_version };
}

$VERSION = eval $VERSION;

our $COUNT     = 1;
our $START     = time;
our $DETACH    = Catalyst::Exception::Detach->new;
our $GO        = Catalyst::Exception::Go->new;

sub import {
    my ( $class, @arguments ) = @_;

    # We have to limit $class to Catalyst to avoid pushing Catalyst upon every
    # callers @ISA.
    return unless $class eq 'Catalyst';

    my $caller = caller();
    return if $caller eq 'main';

    # Kill Adopt::NEXT warnings if we're a non-RC version
    unless (_IS_DEVELOPMENT_VERSION()) {
        Class::C3::Adopt::NEXT->unimport(qr/^Catalyst::/);
    }

    my $meta = Moose::Meta::Class->initialize($caller);
    # Make the caller inherit from Catalyst
    unless ( $caller->isa('Catalyst') ) {
        $meta->superclasses($meta->superclasses, 'Catalyst');
    }
    # Avoid possible C3 issues if 'Moose::Object' is already on RHS of MyApp
    $meta->superclasses(grep { $_ ne 'Moose::Object' } $meta->superclasses);

    unless( $meta->has_method('meta') ){
        $meta->add_method(meta => sub { Moose::Meta::Class->initialize("${caller}") } );
    }

    $caller->arguments( [@arguments] );
    $caller->setup_home;
}

sub _application { $_[0] }

=head1 NAME

Catalyst - The Elegant MVC Web Application Framework

=head1 SYNOPSIS

See the L<Catalyst::Manual> distribution for comprehensive
documentation and tutorials.

    # Install Catalyst::Devel for helpers and other development tools
    # use the helper to create a new application
    catalyst.pl MyApp

    # add models, views, controllers
    script/myapp_create.pl model MyDatabase DBIC::Schema create=static dbi:SQLite:/path/to/db
    script/myapp_create.pl view MyTemplate TT
    script/myapp_create.pl controller Search

    # built in testserver -- use -r to restart automatically on changes
    # --help to see all available options
    script/myapp_server.pl

    # command line testing interface
    script/myapp_test.pl /yada

    ### in lib/MyApp.pm
    use Catalyst qw/-Debug/; # include plugins here as well

    ### In lib/MyApp/Controller/Root.pm (autocreated)
    sub foo : Global { # called for /foo, /foo/1, /foo/1/2, etc.
        my ( $self, $c, @args ) = @_; # args are qw/1 2/ for /foo/1/2
        $c->stash->{template} = 'foo.tt'; # set the template
        # lookup something from db -- stash vars are passed to TT
        $c->stash->{data} =
          $c->model('Database::Foo')->search( { country => $args[0] } );
        if ( $c->req->params->{bar} ) { # access GET or POST parameters
            $c->forward( 'bar' ); # process another action
            # do something else after forward returns
        }
    }

    # The foo.tt TT template can use the stash data from the database
    [% WHILE (item = data.next) %]
        [% item.foo %]
    [% END %]

    # called for /bar/of/soap, /bar/of/soap/10, etc.
    sub bar : Path('/bar/of/soap') { ... }

    # called for all actions, from the top-most controller downwards
    sub auto : Private {
        my ( $self, $c ) = @_;
        if ( !$c->user_exists ) { # Catalyst::Plugin::Authentication
            $c->res->redirect( '/login' ); # require login
            return 0; # abort request and go immediately to end()
        }
        return 1; # success; carry on to next action
    }

    # called after all actions are finished
    sub end : Private {
        my ( $self, $c ) = @_;
        if ( scalar @{ $c->error } ) { ... } # handle errors
        return if $c->res->body; # already have a response
        $c->forward( 'MyApp::View::TT' ); # render template
    }

    ### in MyApp/Controller/Foo.pm
    # called for /foo/bar
    sub bar : Local { ... }

    # called for /blargle
    sub blargle : Global { ... }

    # an index action matches /foo, but not /foo/1, etc.
    sub index : Private { ... }

    ### in MyApp/Controller/Foo/Bar.pm
    # called for /foo/bar/baz
    sub baz : Local { ... }

    # first Root auto is called, then Foo auto, then this
    sub auto : Private { ... }

    # powerful regular expression paths are also possible
    sub details : Regex('^product/(\w+)/details$') {
        my ( $self, $c ) = @_;
        # extract the (\w+) from the URI
        my $product = $c->req->captures->[0];
    }

See L<Catalyst::Manual::Intro> for additional information.

=head1 DESCRIPTION

Catalyst is a modern framework for making web applications without the
pain usually associated with this process. This document is a reference
to the main Catalyst application. If you are a new user, we suggest you
start with L<Catalyst::Manual::Tutorial> or L<Catalyst::Manual::Intro>.

See L<Catalyst::Manual> for more documentation.

Catalyst plugins can be loaded by naming them as arguments to the "use
Catalyst" statement. Omit the C<Catalyst::Plugin::> prefix from the
plugin name, i.e., C<Catalyst::Plugin::My::Module> becomes
C<My::Module>.

    use Catalyst qw/My::Module/;

If your plugin starts with a name other than C<Catalyst::Plugin::>, you can
fully qualify the name by using a unary plus:

    use Catalyst qw/
        My::Module
        +Fully::Qualified::Plugin::Name
    /;

Special flags like C<-Debug> and C<-Engine> can also be specified as
arguments when Catalyst is loaded:

    use Catalyst qw/-Debug My::Module/;

The position of plugins and flags in the chain is important, because
they are loaded in the order in which they appear.

The following flags are supported:

=head2 -Debug

Enables debug output. You can also force this setting from the system
environment with CATALYST_DEBUG or <MYAPP>_DEBUG. The environment
settings override the application, with <MYAPP>_DEBUG having the highest
priority.

=head2 -Engine

Forces Catalyst to use a specific engine. Omit the
C<Catalyst::Engine::> prefix of the engine name, i.e.:

    use Catalyst qw/-Engine=CGI/;

=head2 -Home

Forces Catalyst to use a specific home directory, e.g.:

    use Catalyst qw[-Home=/usr/mst];

This can also be done in the shell environment by setting either the
C<CATALYST_HOME> environment variable or C<MYAPP_HOME>; where C<MYAPP>
is replaced with the uppercased name of your application, any "::" in
the name will be replaced with underscores, e.g. MyApp::Web should use
MYAPP_WEB_HOME. If both variables are set, the MYAPP_HOME one will be used.

=head2 -Log

    use Catalyst '-Log=warn,fatal,error';

Specifies a comma-delimited list of log levels.

=head2 -Stats

Enables statistics collection and reporting. You can also force this setting
from the system environment with CATALYST_STATS or <MYAPP>_STATS. The
environment settings override the application, with <MYAPP>_STATS having the
highest priority.

e.g.

   use Catalyst qw/-Stats=1/

=head1 METHODS

=cut

=head2 $c->controller($name)

Gets a L<Catalyst::Controller> instance by name.

    $c->controller('Foo')->do_stuff;

If the name is omitted, will return the controller for the dispatched
action.

If you want to search for controllers, pass in a regexp as the argument.

    # find all controllers that start with Foo
    my @foo_controllers = $c->controller(qr{^Foo});


=cut

sub controller {
    my ( $c, $name, @args ) = @_;

    if( $name ) {
        my @result = $c->_comp_search_prefixes( $name, qw/Controller C/ );
        return map { $c->_filter_component( $_, @args ) } @result if ref $name;
        return $c->_filter_component( $result[ 0 ], @args );
    }

    return $c->component( $c->action->class );
}

=head2 $c->view($name)

Gets a L<Catalyst::View> instance by name.

=cut

sub view {
    my ( $c, $name, @args ) = @_;

    if( $name ) {
        my @result = $c->_comp_search_prefixes( $name, qw/View V/ );
        return map { $c->_filter_component( $_, @args ) } @result if ref $name;
        return $c->_filter_component( $result[ 0 ], @args );
    }

    return $c->view( $c->config->{default_view} )
      if $c->config->{default_view};
    my( $comp, $rest ) = $c->_comp_search_prefixes( undef, qw/View V/);

    if( $rest ) {
        $c->log->warn( 'Calling $c->view() will return a random view unless you specify one of:' );
        $c->log->warn( '* $c->config(default_view => "the name of the default view to use")' );
        $c->log->warn( '* $c->stash->{current_view} # the name of the view to use for this request' );
        $c->log->warn( '* $c->stash->{current_view_instance} # the instance of the view to use for this request' );
        $c->log->warn( 'NB: in version 5.81, the "random" behavior will not work at all.' );
    }

    return $c->_filter_component( $comp );
}

=head2 $c->model($name)

Gets a L<Catalyst::Model> instance by name.

=cut

sub model {
    my ( $c, $name, @args ) = @_;
    if( $name ) {
        my @result = $c->_comp_search_prefixes( $name, qw/Model M/ );
        return map { $c->_filter_component( $_, @args ) } @result if ref $name;
        return $c->_filter_component( $result[ 0 ], @args );
    }

    return $c->model( $c->config->{default_model} )
      if $c->config->{default_model};

    my( $comp, $rest ) = $c->_comp_search_prefixes( undef, qw/Model M/);

    if( $rest ) {
        $c->log->warn( Carp::shortmess('Calling $c->model() will return a random model unless you specify one of:') );
        $c->log->warn( '* $c->config(default_model => "the name of the default model to use")' );
        $c->log->warn( '* $c->stash->{current_model} # the name of the model to use for this request' );
        $c->log->warn( '* $c->stash->{current_model_instance} # the instance of the model to use for this request' );
        $c->log->warn( 'NB: in version 5.81, the "random" behavior will not work at all.' );
    }

    return $c->_filter_component( $comp );
}


sub _comp_search_prefixes {
    my $c = shift;
    return map $c->components->{ $_ }, $c->_comp_names_search_prefixes(@_);
}

# search components given a name and some prefixes
sub _comp_names_search_prefixes {
    my ( $c, $name, @prefixes ) = @_;
    my $appclass = ref $c || $c;
    my $filter   = "^${appclass}::(" . join( '|', @prefixes ) . ')::';
    $filter = qr/$filter/; # Compile regex now rather than once per loop

    # map the original component name to the sub part that we will search against
    my %eligible = map { my $n = $_; $n =~ s{^$appclass\::[^:]+::}{}; $_ => $n; }
        grep { /$filter/ } keys %{ $c->components };

    # undef for a name will return all
    return keys %eligible if !defined $name;

    my $query  = ref $name ? $name : qr/^$name$/i;
    my @result = grep { $eligible{$_} =~ m{$query} } keys %eligible;

    return @result if @result;

    # if we were given a regexp to search against, we're done.
    return if ref $name;

    # skip regexp fallback if configured
    return
        if $appclass->config->{disable_component_resolution_regex_fallback};

    # regexp fallback
    $query  = qr/$name/i;
    @result = grep { $eligible{ $_ } =~ m{$query} } keys %eligible;

    # no results? try against full names
    if( !@result ) {
        @result = grep { m{$query} } keys %eligible;
    }

    # don't warn if we didn't find any results, it just might not exist
    if( @result ) {
        # Disgusting hack to work out correct method name
        my $warn_for = lc $prefixes[0];
        my $msg = "Used regexp fallback for \$c->${warn_for}('${name}'), which found '" .
           (join '", "', @result) . "'. Relying on regexp fallback behavior for " .
           "component resolution is unreliable and unsafe.";
        my $short = $result[0];
        # remove the component namespace prefix
        $short =~ s/.*?(Model|Controller|View):://;
        my $shortmess = Carp::shortmess('');
        if ($shortmess =~ m#Catalyst/Plugin#) {
           $msg .= " You probably need to set '$short' instead of '${name}' in this " .
              "plugin's config";
        } elsif ($shortmess =~ m#Catalyst/lib/(View|Controller)#) {
           $msg .= " You probably need to set '$short' instead of '${name}' in this " .
              "component's config";
        } else {
           $msg .= " You probably meant \$c->${warn_for}('$short') instead of \$c->${warn_for}('${name}'), " .
              "but if you really wanted to search, pass in a regexp as the argument " .
              "like so: \$c->${warn_for}(qr/${name}/)";
        }
        $c->log->warn( "${msg}$shortmess" );
    }

    return @result;
}

# Find possible names for a prefix
sub _comp_names {
    my ( $c, @prefixes ) = @_;
    my $appclass = ref $c || $c;

    my $filter = "^${appclass}::(" . join( '|', @prefixes ) . ')::';

    my @names = map { s{$filter}{}; $_; }
        $c->_comp_names_search_prefixes( undef, @prefixes );

    return @names;
}

# Filter a component before returning by calling ACCEPT_CONTEXT if available
sub _filter_component {
    my ( $c, $comp, @args ) = @_;

    if ( eval { $comp->can('ACCEPT_CONTEXT'); } ) {
        return $comp->ACCEPT_CONTEXT( $c, @args );
    }

    return $comp;
}

=head2 COMPONENT ACCESSORS

=head2 $c->controllers

Returns the available names which can be passed to $c->controller

=cut

sub controllers {
    my ( $c ) = @_;
    return $c->_comp_names(qw/Controller C/);
}

=head2 $c->models

Returns the available names which can be passed to $c->model

=cut

sub models {
    my ( $c ) = @_;
    return $c->_comp_names(qw/Model M/);
}


=head2 $c->views

Returns the available names which can be passed to $c->view

=cut

sub views {
    my ( $c ) = @_;
    return $c->_comp_names(qw/View V/);
}

=head2 $c->comp($name)

=head2 $c->component($name)

Gets a component object by name. This method is not recommended,
unless you want to get a specific component by full
class. C<< $c->controller >>, C<< $c->model >>, and C<< $c->view >>
should be used instead.

If C<$name> is a regexp, a list of components matched against the full
component name will be returned.

If Catalyst can't find a component by name, it will fallback to regex
matching by default. To disable this behaviour set
disable_component_resolution_regex_fallback to a true value.
    
    __PACKAGE__->config( disable_component_resolution_regex_fallback => 1 );

=cut

sub component {
    my ( $c, $name, @args ) = @_;

    if( $name ) {
        my $comps = $c->components;

        if( !ref $name ) {
            # is it the exact name?
            return $c->_filter_component( $comps->{ $name }, @args )
                       if exists $comps->{ $name };

            # perhaps we just omitted "MyApp"?
            my $composed = ( ref $c || $c ) . "::${name}";
            return $c->_filter_component( $comps->{ $composed }, @args )
                       if exists $comps->{ $composed };

            # search all of the models, views and controllers
            my( $comp ) = $c->_comp_search_prefixes( $name, qw/Model M Controller C View V/ );
            return $c->_filter_component( $comp, @args ) if $comp;
        }

        # This is here so $c->comp( '::M::' ) works
        my $query = ref $name ? $name : qr{$name}i;

        my @result = grep { m{$query} } keys %{ $c->components };
        return map { $c->_filter_component( $_, @args ) } @result if ref $name;

        if( $result[ 0 ] ) {
            $c->log->warn( Carp::shortmess(qq(Found results for "${name}" using regexp fallback)) );
            $c->log->warn( 'Relying on the regexp fallback behavior for component resolution' );
            $c->log->warn( 'is unreliable and unsafe. You have been warned' );
            return $c->_filter_component( $result[ 0 ], @args );
        }

        # I would expect to return an empty list here, but that breaks back-compat
    }

    # fallback
    return sort keys %{ $c->components };
}

=head2 CLASS DATA AND HELPER CLASSES

=head2 $c->config

Returns or takes a hashref containing the application's configuration.

    __PACKAGE__->config( { db => 'dsn:SQLite:foo.db' } );

You can also use a C<YAML>, C<XML> or L<Config::General> config file
like C<myapp.conf> in your applications home directory. See
L<Catalyst::Plugin::ConfigLoader>.

=head3 Cascading configuration

The config method is present on all Catalyst components, and configuration
will be merged when an application is started. Configuration loaded with
L<Catalyst::Plugin::ConfigLoader> takes precedence over other configuration,
followed by configuration in your top level C<MyApp> class. These two
configurations are merged, and then configuration data whose hash key matches a
component name is merged with configuration for that component.

The configuration for a component is then passed to the C<new> method when a
component is constructed.

For example:

    MyApp->config({ 'Model::Foo' => { bar => 'baz', overrides => 'me' } });
    MyApp::Model::Foo->config({ quux => 'frob', 'overrides => 'this' });

will mean that C<MyApp::Model::Foo> receives the following data when
constructed:

    MyApp::Model::Foo->new({
        bar => 'baz',
        quux => 'frob',
        overrides => 'me',
    });

=cut

around config => sub {
    my $orig = shift;
    my $c = shift;

    croak('Setting config after setup has been run is not allowed.')
        if ( @_ and $c->setup_finished );

    $c->$orig(@_);
};

=head2 $c->log

Returns the logging object instance. Unless it is already set, Catalyst
sets this up with a L<Catalyst::Log> object. To use your own log class,
set the logger with the C<< __PACKAGE__->log >> method prior to calling
C<< __PACKAGE__->setup >>.

 __PACKAGE__->log( MyLogger->new );
 __PACKAGE__->setup;

And later:

    $c->log->info( 'Now logging with my own logger!' );

Your log class should implement the methods described in
L<Catalyst::Log>.


=head2 $c->debug

Returns 1 if debug mode is enabled, 0 otherwise.

You can enable debug mode in several ways:

=over

=item By calling myapp_server.pl with the -d flag

=item With the environment variables MYAPP_DEBUG, or CATALYST_DEBUG

=item The -Debug option in your MyApp.pm

=item By declaring C<sub debug { 1 }> in your MyApp.pm.

=back

Calling C<< $c->debug(1) >> has no effect.

=cut

sub debug { 0 }

=head2 $c->dispatcher

Returns the dispatcher instance. See L<Catalyst::Dispatcher>.

=head2 $c->engine

Returns the engine instance. See L<Catalyst::Engine>.


=head2 UTILITY METHODS

=head2 $c->path_to(@path)

Merges C<@path> with C<< $c->config->{home} >> and returns a
L<Path::Class::Dir> object. Note you can usually use this object as
a filename, but sometimes you will have to explicitly stringify it
yourself by calling the C<< ->stringify >> method.

For example:

    $c->path_to( 'db', 'sqlite.db' );

=cut

sub path_to {
    my ( $c, @path ) = @_;
    my $path = Path::Class::Dir->new( $c->config->{home}, @path );
    if ( -d $path ) { return $path }
    else { return Path::Class::File->new( $c->config->{home}, @path ) }
}

=head2 $c->plugin( $name, $class, @args )

Helper method for plugins. It creates a class data accessor/mutator and
loads and instantiates the given class.

    MyApp->plugin( 'prototype', 'HTML::Prototype' );

    $c->prototype->define_javascript_functions;

B<Note:> This method of adding plugins is deprecated. The ability
to add plugins like this B<will be removed> in a Catalyst 5.81.
Please do not use this functionality in new code.

=cut

sub plugin {
    my ( $class, $name, $plugin, @args ) = @_;

    # See block comment in t/unit_core_plugin.t
    $class->log->warn(qq/Adding plugin using the ->plugin method is deprecated, and will be removed in Catalyst 5.81/);

    $class->_register_plugin( $plugin, 1 );

    eval { $plugin->import };
    $class->mk_classdata($name);
    my $obj;
    eval { $obj = $plugin->new(@args) };

    if ($@) {
        Catalyst::Exception->throw( message =>
              qq/Couldn't instantiate instant plugin "$plugin", "$@"/ );
    }

    $class->$name($obj);
    $class->log->debug(qq/Initialized instant plugin "$plugin" as "$name"/)
      if $class->debug;
}

=head2 MyApp->setup

Initializes the dispatcher and engine, loads any plugins, and loads the
model, view, and controller components. You may also specify an array
of plugins to load here, if you choose to not load them in the C<use
Catalyst> line.

    MyApp->setup;
    MyApp->setup( qw/-Debug/ );

=cut

sub setup {
    my ( $class, @arguments ) = @_;
    croak('Running setup more than once')
        if ( $class->setup_finished );

    unless ( $class->isa('Catalyst') ) {

        Catalyst::Exception->throw(
            message => qq/'$class' does not inherit from Catalyst/ );
    }

    if ( $class->arguments ) {
        @arguments = ( @arguments, @{ $class->arguments } );
    }

    # Process options
    my $flags = {};

    foreach (@arguments) {

        if (/^-Debug$/) {
            $flags->{log} =
              ( $flags->{log} ) ? 'debug,' . $flags->{log} : 'debug';
        }
        elsif (/^-(\w+)=?(.*)$/) {
            $flags->{ lc $1 } = $2;
        }
        else {
            push @{ $flags->{plugins} }, $_;
        }
    }

    $class->setup_home( delete $flags->{home} );

    $class->setup_log( delete $flags->{log} );
    $class->setup_plugins( delete $flags->{plugins} );
    $class->setup_dispatcher( delete $flags->{dispatcher} );
    $class->setup_engine( delete $flags->{engine} );
    $class->setup_stats( delete $flags->{stats} );

    for my $flag ( sort keys %{$flags} ) {

        if ( my $code = $class->can( 'setup_' . $flag ) ) {
            &$code( $class, delete $flags->{$flag} );
        }
        else {
            $class->log->warn(qq/Unknown flag "$flag"/);
        }
    }

    eval { require Catalyst::Devel; };
    if( !$@ && $ENV{CATALYST_SCRIPT_GEN} && ( $ENV{CATALYST_SCRIPT_GEN} < $Catalyst::Devel::CATALYST_SCRIPT_GEN ) ) {
        $class->log->warn(<<"EOF");
You are running an old script!

  Please update by running (this will overwrite existing files):
    catalyst.pl -force -scripts $class

  or (this will not overwrite existing files):
    catalyst.pl -scripts $class

EOF
    }

    if ( $class->debug ) {
        my @plugins = map { "$_  " . ( $_->VERSION || '' ) } $class->registered_plugins;

        if (@plugins) {
            my $column_width = Catalyst::Utils::term_width() - 6;
            my $t = Text::SimpleTable->new($column_width);
            $t->row($_) for @plugins;
            $class->log->debug( "Loaded plugins:\n" . $t->draw . "\n" );
        }

        my $dispatcher = $class->dispatcher;
        my $engine     = $class->engine;
        my $home       = $class->config->{home};

        $class->log->debug(sprintf(q/Loaded dispatcher "%s"/, blessed($dispatcher)));
        $class->log->debug(sprintf(q/Loaded engine "%s"/, blessed($engine)));

        $home
          ? ( -d $home )
          ? $class->log->debug(qq/Found home "$home"/)
          : $class->log->debug(qq/Home "$home" doesn't exist/)
          : $class->log->debug(q/Couldn't find home/);
    }

    # Call plugins setup, this is stupid and evil.
    # Also screws C3 badly on 5.10, hack to avoid.
    {
        no warnings qw/redefine/;
        local *setup = sub { };
        $class->setup unless $Catalyst::__AM_RESTARTING;
    }

    # Initialize our data structure
    $class->components( {} );

    $class->setup_components;

    if ( $class->debug ) {
        my $column_width = Catalyst::Utils::term_width() - 8 - 9;
        my $t = Text::SimpleTable->new( [ $column_width, 'Class' ], [ 8, 'Type' ] );
        for my $comp ( sort keys %{ $class->components } ) {
            my $type = ref $class->components->{$comp} ? 'instance' : 'class';
            $t->row( $comp, $type );
        }
        $class->log->debug( "Loaded components:\n" . $t->draw . "\n" )
          if ( keys %{ $class->components } );
    }

    $class->setup_actions;

    if ( $class->debug ) {
        my $name = $class->config->{name} || 'Application';
        $class->log->info("$name powered by Catalyst $Catalyst::VERSION");
    }

    # Make sure that the application class becomes immutable at this point,
    B::Hooks::EndOfScope::on_scope_end {
        return if $@;
        my $meta = Class::MOP::get_metaclass_by_name($class);
        if (
            $meta->is_immutable
            && ! { $meta->immutable_options }->{replace_constructor}
            && (
                   $class->isa('Class::Accessor::Fast')
                || $class->isa('Class::Accessor')
            )
        ) {
            warn "You made your application class ($class) immutable, "
                . "but did not inline the\nconstructor. "
                . "This will break catalyst, as your app \@ISA "
                . "Class::Accessor(::Fast)?\nPlease pass "
                . "(replace_constructor => 1)\nwhen making your class immutable.\n";
        }
        $meta->make_immutable(
            replace_constructor => 1,
        ) unless $meta->is_immutable;
    };

    $class->setup_finalize;
    # Should be the last thing we do so that user things hooking
    # setup_finalize can log..
    $class->log->_flush() if $class->log->can('_flush');
    return 1; # Explicit return true as people have __PACKAGE__->setup as the last thing in their class. HATE.
}


=head2 $app->setup_finalize

A hook to attach modifiers to.
Using C<< after setup => sub{}; >> doesn't work, because of quirky things done for plugin setup.
Also better than C< setup_finished(); >, as that is a getter method.

    sub setup_finalize {

        my $app = shift;

        ## do stuff, i.e., determine a primary key column for sessions stored in a DB

        $app->next::method(@_);


    }

=cut

sub setup_finalize {
    my ($class) = @_;
    $class->setup_finished(1);
}

=head2 $c->welcome_message

Returns the Catalyst welcome HTML page.

=cut

sub welcome_message {
    my $c      = shift;
    my $name   = $c->config->{name};
    my $logo   = $c->uri_for('/static/images/catalyst_logo.png');
    my $prefix = Catalyst::Utils::appprefix( ref $c );
    $c->response->content_type('text/html; charset=utf-8');
    return <<"EOF";
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
    <head>
    <meta http-equiv="Content-Language" content="en" />
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
        <title>$name on Catalyst $VERSION</title>
        <style type="text/css">
            body {
                color: #000;
                background-color: #eee;
            }
            div#content {
                width: 640px;
                margin-left: auto;
                margin-right: auto;
                margin-top: 10px;
                margin-bottom: 10px;
                text-align: left;
                background-color: #ccc;
                border: 1px solid #aaa;
            }
            p, h1, h2 {
                margin-left: 20px;
                margin-right: 20px;
                font-family: verdana, tahoma, sans-serif;
            }
            a {
                font-family: verdana, tahoma, sans-serif;
            }
            :link, :visited {
                    text-decoration: none;
                    color: #b00;
                    border-bottom: 1px dotted #bbb;
            }
            :link:hover, :visited:hover {
                    color: #555;
            }
            div#topbar {
                margin: 0px;
            }
            pre {
                margin: 10px;
                padding: 8px;
            }
            div#answers {
                padding: 8px;
                margin: 10px;
                background-color: #fff;
                border: 1px solid #aaa;
            }
            h1 {
                font-size: 0.9em;
                font-weight: normal;
                text-align: center;
            }
            h2 {
                font-size: 1.0em;
            }
            p {
                font-size: 0.9em;
            }
            p img {
                float: right;
                margin-left: 10px;
            }
            span#appname {
                font-weight: bold;
                font-size: 1.6em;
            }
        </style>
    </head>
    <body>
        <div id="content">
            <div id="topbar">
                <h1><span id="appname">$name</span> on <a href="http://catalyst.perl.org">Catalyst</a>
                    $VERSION</h1>
             </div>
             <div id="answers">
                 <p>
                 <img src="$logo" alt="Catalyst Logo" />
                 </p>
                 <p>Welcome to the  world of Catalyst.
                    This <a href="http://en.wikipedia.org/wiki/MVC">MVC</a>
                    framework will make web development something you had
                    never expected it to be: Fun, rewarding, and quick.</p>
                 <h2>What to do now?</h2>
                 <p>That really depends  on what <b>you</b> want to do.
                    We do, however, provide you with a few starting points.</p>
                 <p>If you want to jump right into web development with Catalyst
                    you might want to start with a tutorial.</p>
<pre>perldoc <a href="http://cpansearch.perl.org/dist/Catalyst-Manual/lib/Catalyst/Manual/Tutorial.pod">Catalyst::Manual::Tutorial</a></code>
</pre>
<p>Afterwards you can go on to check out a more complete look at our features.</p>
<pre>
<code>perldoc <a href="http://cpansearch.perl.org/dist/Catalyst-Manual/lib/Catalyst/Manual/Intro.pod">Catalyst::Manual::Intro</a>
<!-- Something else should go here, but the Catalyst::Manual link seems unhelpful -->
</code></pre>
                 <h2>What to do next?</h2>
                 <p>Next it's time to write an actual application. Use the
                    helper scripts to generate <a href="http://cpansearch.perl.org/search?query=Catalyst%3A%3AController%3A%3A&amp;mode=all">controllers</a>,
                    <a href="http://cpansearch.perl.org/search?query=Catalyst%3A%3AModel%3A%3A&amp;mode=all">models</a>, and
                    <a href="http://cpansearch.perl.org/search?query=Catalyst%3A%3AView%3A%3A&amp;mode=all">views</a>;
                    they can save you a lot of work.</p>
                    <pre><code>script/${prefix}_create.pl -help</code></pre>
                    <p>Also, be sure to check out the vast and growing
                    collection of <a href="http://search.cpan.org/search?query=Catalyst">plugins for Catalyst on CPAN</a>;
                    you are likely to find what you need there.
                    </p>

                 <h2>Need help?</h2>
                 <p>Catalyst has a very active community. Here are the main places to
                    get in touch with us.</p>
                 <ul>
                     <li>
                         <a href="http://dev.catalyst.perl.org">Wiki</a>
                     </li>
                     <li>
                         <a href="http://lists.scsys.co.uk/cgi-bin/mailman/listinfo/catalyst">Mailing-List</a>
                     </li>
                     <li>
                         <a href="irc://irc.perl.org/catalyst">IRC channel #catalyst on irc.perl.org</a>
                     </li>
                 </ul>
                 <h2>In conclusion</h2>
                 <p>The Catalyst team hopes you will enjoy using Catalyst as much
                    as we enjoyed making it. Please contact us if you have ideas
                    for improvement or other feedback.</p>
             </div>
         </div>
    </body>
</html>
EOF
}

=head1 INTERNAL METHODS

These methods are not meant to be used by end users.

=head2 $c->components

Returns a hash of components.

=head2 $c->context_class

Returns or sets the context class.

=head2 $c->dispatcher_class

Returns or sets the dispatcher class.

=head2 $c->engine_class

Returns or sets the engine class.

=head2 $c->handle_request( $class, @arguments )

Called to handle each HTTP request.

=cut

sub handle_request {
    my ( $class, @arguments ) = @_;

    # Always expect worst case!
    my $status = -1;
    eval {
        if ($class->debug) {
            my $secs = time - $START || 1;
            my $av = sprintf '%.3f', $COUNT / $secs;
            my $time = localtime time;
            $class->log->info("*** Request $COUNT ($av/s) [$$] [$time] ***");
        }

        my $c = $class->prepare(@arguments);
        $c->dispatch;
        $status = $c->finalize;
    };

    if ( my $error = $@ ) {
        chomp $error;
        $class->log->error(qq/Caught exception in engine "$error"/);
    }

    $COUNT++;

    if(my $coderef = $class->log->can('_flush')){
        $class->log->$coderef();
    }
    return $status;
}

=head2 $c->prepare( @arguments )

Creates a Catalyst context from an engine-specific request (Apache, CGI,
etc.).

=cut

sub prepare {
    my ( $class, @arguments ) = @_;

    # XXX
    # After the app/ctxt split, this should become an attribute based on something passed
    # into the application.
    $class->context_class( ref $class || $class ) unless $class->context_class;

    my $app = $class->new({});
    my $c = $class->context_class->new( application => $app );

    # For on-demand data
    $c->request->_context($c);
    $c->response->_context($c);

    #surely this is not the most efficient way to do things...
    $c->stats($class->stats_class->new)->enable($c->use_stats);
    if ( $c->debug ) {
        $c->res->headers->header( 'X-Catalyst' => $Catalyst::VERSION );
    }

    #XXX reuse coderef from can
    # Allow engine to direct the prepare flow (for POE)
    if ( $c->engine->can('prepare') ) {
        $c->engine->prepare( $c, @arguments );
    }
    else {
        $c->prepare_request(@arguments);
        $c->prepare_connection;
        $c->prepare_query_parameters;
        $c->prepare_headers;
        $c->prepare_cookies;
        $c->prepare_path;

        # Prepare the body for reading, either by prepare_body
        # or the user, if they are using $c->read
        $c->prepare_read;

        # Parse the body unless the user wants it on-demand
        unless ( $app->config->{parse_on_demand} ) {
            $c->prepare_body;
        }
    }

    my $method  = $c->req->method  || '';
    my $path    = $c->req->path;
    $path       = '/' unless length $path;
    my $address = $c->req->address || '';

    $c->log->debug(qq/"$method" request for "$path" from "$address"/)
      if $c->debug;

    $c->prepare_action;

    return $c;
}

=head2 $c->request_class

Returns or sets the request class.

=head2 $c->response_class

Returns or sets the response class.

=head2 $c->run

Starts the engine.

=cut

sub run { my $c = shift; return $c->engine->run( $c, @_ ) }

=head2 $c->set_action( $action, $code, $namespace, $attrs )

Sets an action in a given namespace.

=cut

sub set_action { my $c = shift; $c->dispatcher->set_action( $c, @_ ) }

=head2 $c->setup_actions($component)

Sets up actions for a component.

=cut

sub setup_actions { my $c = shift; $c->dispatcher->setup_actions( $c, @_ ) }

=head2 $c->setup_components

This method is called internally to set up the application's components.

It finds modules by calling the L<locate_components> method, expands them to
package names with the L<expand_component_module> method, and then installs
each component into the application.

The C<setup_components> config option is passed to both of the above methods.

Installation of each component is performed by the L<setup_component> method,
below.

=cut

sub setup_components {
    my $class = shift;

    my $config  = $class->config->{ setup_components };

    my @comps = sort { length $a <=> length $b }
                $class->locate_components($config);
    my %comps = map { $_ => 1 } @comps;

    my $deprecatedcatalyst_component_names = grep { /::[CMV]::/ } @comps;
    $class->log->warn(qq{Your application is using the deprecated ::[MVC]:: type naming scheme.\n}.
        qq{Please switch your class names to ::Model::, ::View:: and ::Controller: as appropriate.\n}
    ) if $deprecatedcatalyst_component_names;

    for my $component ( @comps ) {

        # We pass ignore_loaded here so that overlay files for (e.g.)
        # Model::DBI::Schema sub-classes are loaded - if it's in @comps
        # we know M::P::O found a file on disk so this is safe

        Catalyst::Utils::ensure_class_loaded( $component, { ignore_loaded => 1 } );

        # Needs to be done as soon as the component is loaded, as loading a sub-component
        # (next time round the loop) can cause us to get the wrong metaclass..
        $class->_controller_init_base_classes($component);
    }

    for my $component (@comps) {
        $class->components->{ $component } = $class->setup_component($component);
        for my $component ($class->expand_component_module( $component, $config )) {
            next if $comps{$component};
            $class->_controller_init_base_classes($component); # Also cover inner packages
            $class->components->{ $component } = $class->setup_component($component);
        }
    }
}

=head2 $c->locate_components( $setup_component_config )

This method is meant to provide a list of component modules that should be
setup for the application.  By default, it will use L<Module::Pluggable>.

Specify a C<setup_components> config option to pass additional options directly
to L<Module::Pluggable>. To add additional search paths, specify a key named
C<search_extra> as an array reference. Items in the array beginning with C<::>
will have the application class name prepended to them.

=cut

sub locate_components {
    my $class  = shift;
    my $config = shift;

    my @paths   = qw( ::Controller ::C ::Model ::M ::View ::V );
    my $extra   = delete $config->{ search_extra } || [];

    push @paths, @$extra;

    my $locator = Module::Pluggable::Object->new(
        search_path => [ map { s/^(?=::)/$class/; $_; } @paths ],
        %$config
    );

    my @comps = $locator->plugins;

    return @comps;
}

=head2 $c->expand_component_module( $component, $setup_component_config )

Components found by C<locate_components> will be passed to this method, which
is expected to return a list of component (package) names to be set up.

=cut

sub expand_component_module {
    my ($class, $module) = @_;
    return Devel::InnerPackage::list_packages( $module );
}

=head2 $c->setup_component

=cut

# FIXME - Ugly, ugly hack to ensure the we force initialize non-moose base classes
#         nearest to Catalyst::Controller first, no matter what order stuff happens
#         to be loaded. There are TODO tests in Moose for this, see
#         f2391d17574eff81d911b97be15ea51080500003
sub _controller_init_base_classes {
    my ($app_class, $component) = @_;
    return unless $component->isa('Catalyst::Controller');
    foreach my $class ( reverse @{ mro::get_linear_isa($component) } ) {
        Moose::Meta::Class->initialize( $class )
            unless find_meta($class);
    }
}

sub setup_component {
    my( $class, $component ) = @_;

    unless ( $component->can( 'COMPONENT' ) ) {
        return $component;
    }

    my $suffix = Catalyst::Utils::class2classsuffix( $component );
    my $config = $class->config->{ $suffix } || {};
    # Stash catalyst_component_name in the config here, so that custom COMPONENT
    # methods also pass it. local to avoid pointlessly shitting in config
    # for the debug screen, as $component is already the key name.
    local $config->{catalyst_component_name} = $component;

    my $instance = eval { $component->COMPONENT( $class, $config ); };

    if ( my $error = $@ ) {
        chomp $error;
        Catalyst::Exception->throw(
            message => qq/Couldn't instantiate component "$component", "$error"/
        );
    }

    unless (blessed $instance) {
        my $metaclass = Moose::Util::find_meta($component);
        my $method_meta = $metaclass->find_method_by_name('COMPONENT');
        my $component_method_from = $method_meta->associated_metaclass->name;
        my $value = defined($instance) ? $instance : 'undef';
        Catalyst::Exception->throw(
            message =>
            qq/Couldn't instantiate component "$component", COMPONENT() method (from $component_method_from) didn't return an object-like value (value was $value)./
        );
    }
    return $instance;
}

=head2 $c->setup_dispatcher

Sets up dispatcher.

=cut

sub setup_dispatcher {
    my ( $class, $dispatcher ) = @_;

    if ($dispatcher) {
        $dispatcher = 'Catalyst::Dispatcher::' . $dispatcher;
    }

    if ( my $env = Catalyst::Utils::env_value( $class, 'DISPATCHER' ) ) {
        $dispatcher = 'Catalyst::Dispatcher::' . $env;
    }

    unless ($dispatcher) {
        $dispatcher = $class->dispatcher_class;
    }

    Class::MOP::load_class($dispatcher);

    # dispatcher instance
    $class->dispatcher( $dispatcher->new );
}

=head2 $c->setup_engine

Sets up engine.

=cut

sub setup_engine {
    my ( $class, $engine ) = @_;

    if ($engine) {
        $engine = 'Catalyst::Engine::' . $engine;
    }

    if ( my $env = Catalyst::Utils::env_value( $class, 'ENGINE' ) ) {
        $engine = 'Catalyst::Engine::' . $env;
    }

    if ( $ENV{MOD_PERL} ) {
        my $meta = Class::MOP::get_metaclass_by_name($class);

        # create the apache method
        $meta->add_method('apache' => sub { shift->engine->apache });

        my ( $software, $version ) =
          $ENV{MOD_PERL} =~ /^(\S+)\/(\d+(?:[\.\_]\d+)+)/;

        $version =~ s/_//g;
        $version =~ s/(\.[^.]+)\./$1/g;

        if ( $software eq 'mod_perl' ) {

            if ( !$engine ) {

                if ( $version >= 1.99922 ) {
                    $engine = 'Catalyst::Engine::Apache2::MP20';
                }

                elsif ( $version >= 1.9901 ) {
                    $engine = 'Catalyst::Engine::Apache2::MP19';
                }

                elsif ( $version >= 1.24 ) {
                    $engine = 'Catalyst::Engine::Apache::MP13';
                }

                else {
                    Catalyst::Exception->throw( message =>
                          qq/Unsupported mod_perl version: $ENV{MOD_PERL}/ );
                }

            }

            # install the correct mod_perl handler
            if ( $version >= 1.9901 ) {
                *handler = sub  : method {
                    shift->handle_request(@_);
                };
            }
            else {
                *handler = sub ($$) { shift->handle_request(@_) };
            }

        }

        elsif ( $software eq 'Zeus-Perl' ) {
            $engine = 'Catalyst::Engine::Zeus';
        }

        else {
            Catalyst::Exception->throw(
                message => qq/Unsupported mod_perl: $ENV{MOD_PERL}/ );
        }
    }

    unless ($engine) {
        $engine = $class->engine_class;
    }

    Class::MOP::load_class($engine);

    # check for old engines that are no longer compatible
    my $old_engine;
    if ( $engine->isa('Catalyst::Engine::Apache')
        && !Catalyst::Engine::Apache->VERSION )
    {
        $old_engine = 1;
    }

    elsif ( $engine->isa('Catalyst::Engine::Server::Base')
        && Catalyst::Engine::Server->VERSION le '0.02' )
    {
        $old_engine = 1;
    }

    elsif ($engine->isa('Catalyst::Engine::HTTP::POE')
        && $engine->VERSION eq '0.01' )
    {
        $old_engine = 1;
    }

    elsif ($engine->isa('Catalyst::Engine::Zeus')
        && $engine->VERSION eq '0.01' )
    {
        $old_engine = 1;
    }

    if ($old_engine) {
        Catalyst::Exception->throw( message =>
              qq/Engine "$engine" is not supported by this version of Catalyst/
        );
    }

    # engine instance
    $class->engine( $engine->new );
}

=head2 $c->setup_home

Sets up the home directory.

=cut

sub setup_home {
    my ( $class, $home ) = @_;

    if ( my $env = Catalyst::Utils::env_value( $class, 'HOME' ) ) {
        $home = $env;
    }

    $home ||= Catalyst::Utils::home($class);

    if ($home) {
        #I remember recently being scolded for assigning config values like this
        $class->config->{home} ||= $home;
        $class->config->{root} ||= Path::Class::Dir->new($home)->subdir('root');
    }
}

=head2 $c->setup_log

Sets up log by instantiating a L<Catalyst::Log|Catalyst::Log> object and
passing it to C<log()>. Pass in a comma-delimited list of levels to set the
log to.

This method also installs a C<debug> method that returns a true value into the
catalyst subclass if the "debug" level is passed in the comma-delimited list,
or if the C<$CATALYST_DEBUG> environment variable is set to a true value.

Note that if the log has already been setup, by either a previous call to
C<setup_log> or by a call such as C<< __PACKAGE__->log( MyLogger->new ) >>,
that this method won't actually set up the log object.

=cut

sub setup_log {
    my ( $class, $levels ) = @_;

    $levels ||= '';
    $levels =~ s/^\s+//;
    $levels =~ s/\s+$//;
    my %levels = map { $_ => 1 } split /\s*,\s*/, $levels;

    my $env_debug = Catalyst::Utils::env_value( $class, 'DEBUG' );
    if ( defined $env_debug ) {
        $levels{debug} = 1 if $env_debug; # Ugly!
        delete($levels{debug}) unless $env_debug;
    }

    unless ( $class->log ) {
        $class->log( Catalyst::Log->new(keys %levels) );
    }

    if ( $levels{debug} ) {
        Class::MOP::get_metaclass_by_name($class)->add_method('debug' => sub { 1 });
        $class->log->debug('Debug messages enabled');
    }
}

=head2 $c->setup_plugins

Sets up plugins.

=cut

=head2 $c->setup_stats

Sets up timing statistics class.

=cut

sub setup_stats {
    my ( $class, $stats ) = @_;

    Catalyst::Utils::ensure_class_loaded($class->stats_class);

    my $env = Catalyst::Utils::env_value( $class, 'STATS' );
    if ( defined($env) ? $env : ($stats || $class->debug ) ) {
        Class::MOP::get_metaclass_by_name($class)->add_method('use_stats' => sub { 1 });
        $class->log->debug('Statistics enabled');
    }
}


=head2 $c->registered_plugins

Returns a sorted list of the plugins which have either been stated in the
import list or which have been added via C<< MyApp->plugin(@args); >>.

If passed a given plugin name, it will report a boolean value indicating
whether or not that plugin is loaded.  A fully qualified name is required if
the plugin name does not begin with C<Catalyst::Plugin::>.

 if ($c->registered_plugins('Some::Plugin')) {
     ...
 }

=cut

{

    sub registered_plugins {
        my $proto = shift;
        return sort keys %{ $proto->_plugins } unless @_;
        my $plugin = shift;
        return 1 if exists $proto->_plugins->{$plugin};
        return exists $proto->_plugins->{"Catalyst::Plugin::$plugin"};
    }

    sub _register_plugin {
        my ( $proto, $plugin, $instant ) = @_;
        my $class = ref $proto || $proto;

        Class::MOP::load_class( $plugin );

        $proto->_plugins->{$plugin} = 1;
        unless ($instant) {
            no strict 'refs';
            if ( my $meta = Class::MOP::get_metaclass_by_name($class) ) {
              my @superclasses = ($plugin, $meta->superclasses );
              $meta->superclasses(@superclasses);
            } else {
              unshift @{"$class\::ISA"}, $plugin;
            }
        }
        return $class;
    }

    sub setup_plugins {
        my ( $class, $plugins ) = @_;

        $class->_plugins( {} ) unless $class->_plugins;
        $plugins ||= [];

        my @plugins = Catalyst::Utils::resolve_namespace($class . '::Plugin', 'Catalyst::Plugin', @$plugins);

        for my $plugin ( reverse @plugins ) {
            Class::MOP::load_class($plugin);
            my $meta = find_meta($plugin);
            next if $meta && $meta->isa('Moose::Meta::Role');

            $class->_register_plugin($plugin);
        }

        my @roles =
            map { $_->name }
            grep { $_ && blessed($_) && $_->isa('Moose::Meta::Role') }
            map { find_meta($_) }
            @plugins;

        Moose::Util::apply_all_roles(
            $class => @roles
        ) if @roles;
    }
}

=head2 $c->stats_class

Returns or sets the stats (timing statistics) class.

=head2 $c->use_stats

Returns 1 when stats collection is enabled.  Stats collection is enabled
when the -Stats options is set, debug is on or when the <MYAPP>_STATS
environment variable is set.

Note that this is a static method, not an accessor and should be overridden
by declaring C<sub use_stats { 1 }> in your MyApp.pm, not by calling C<< $c->use_stats(1) >>.

=cut

sub use_stats { 0 }

=head2 version

Returns the Catalyst version number. Mostly useful for "powered by"
messages in template systems.

=cut

sub version { return $Catalyst::VERSION }

=head1 CONFIGURATION

There are a number of 'base' config variables which can be set:

=over

=item *

C<default_model> - The default model picked if you say C<< $c->model >>. See L</$c->model($name)>.

=item *

C<default_view> - The default view to be rendered or returned when C<< $c->view >>. See L</$c->view($name)>.
is called.

=item *

C<disable_component_resolution_regex_fallback> - Turns
off the deprecated component resolution functionality so
that if any of the component methods (e.g. C<< $c->controller('Foo') >>)
are called then regex search will not be attempted on string values and
instead C<undef> will be returned.

=item *

C<home> - The application home directory. In an uninstalled application,
this is the top level application directory. In an installed application,
this will be the directory containing C<< MyApp.pm >>.

=item *

C<ignore_frontend_proxy> - See L</PROXY SUPPORT>

=item *

C<name> - The name of the application in debug messages and the debug and
welcome screens

=item *

C<parse_on_demand> - The request body (for example file uploads) will not be parsed
until it is accessed. This allows you to (for example) check authentication (and reject
the upload) before actually recieving all the data. See L</ON-DEMAND PARSER>

=item *

C<root> - The root directory for templates. Usually this is just a
subdirectory of the home directory, but you can set it to change the
templates to a different directory.

=item *

C<search_extra> - Array reference passed to Module::Pluggable to for additional
namespaces from which components will be loaded (and constructed and stored in
C<< $c->components >>).

=item *

C<show_internal_actions> - If true, causes internal actions such as C<< _DISPATCH >>
to be shown in hit debug tables in the test server.

=item *

C<using_frontend_proxy> - See L</PROXY SUPPORT>.

=back

=head1 INTERNAL ACTIONS

Catalyst uses internal actions like C<_DISPATCH>, C<_BEGIN>, C<_AUTO>,
C<_ACTION>, and C<_END>. These are by default not shown in the private
action table, but you can make them visible with a config parameter.

    MyApp->config(show_internal_actions => 1);

=head1 ON-DEMAND PARSER

The request body is usually parsed at the beginning of a request,
but if you want to handle input yourself, you can enable on-demand
parsing with a config parameter.

    MyApp->config(parse_on_demand => 1);

=head1 PROXY SUPPORT

Many production servers operate using the common double-server approach,
with a lightweight frontend web server passing requests to a larger
backend server. An application running on the backend server must deal
with two problems: the remote user always appears to be C<127.0.0.1> and
the server's hostname will appear to be C<localhost> regardless of the
virtual host that the user connected through.

Catalyst will automatically detect this situation when you are running
the frontend and backend servers on the same machine. The following
changes are made to the request.

    $c->req->address is set to the user's real IP address, as read from
    the HTTP X-Forwarded-For header.

    The host value for $c->req->base and $c->req->uri is set to the real
    host, as read from the HTTP X-Forwarded-Host header.

Additionally, you may be running your backend application on an insecure
connection (port 80) while your frontend proxy is running under SSL.  If there
is a discrepancy in the ports, use the HTTP header C<X-Forwarded-Port> to
tell Catalyst what port the frontend listens on.  This will allow all URIs to
be created properly.

In the case of passing in:

    X-Forwarded-Port: 443

All calls to C<uri_for> will result in an https link, as is expected.

Obviously, your web server must support these headers for this to work.

In a more complex server farm environment where you may have your
frontend proxy server(s) on different machines, you will need to set a
configuration option to tell Catalyst to read the proxied data from the
headers.

    MyApp->config(using_frontend_proxy => 1);

If you do not wish to use the proxy support at all, you may set:

    MyApp->config(ignore_frontend_proxy => 1);

=head1 THREAD SAFETY

Catalyst has been tested under Apache 2's threading C<mpm_worker>,
C<mpm_winnt>, and the standalone forking HTTP server on Windows. We
believe the Catalyst core to be thread-safe.

If you plan to operate in a threaded environment, remember that all other
modules you are using must also be thread-safe. Some modules, most notably
L<DBD::SQLite>, are not thread-safe.

=head1 SUPPORT

IRC:

    Join #catalyst on irc.perl.org.

Mailing Lists:

    http://lists.scsys.co.uk/cgi-bin/mailman/listinfo/catalyst
    http://lists.scsys.co.uk/cgi-bin/mailman/listinfo/catalyst-dev

Web:

    http://catalyst.perl.org

Wiki:

    http://dev.catalyst.perl.org

=head1 SEE ALSO

=head2 L<Task::Catalyst> - All you need to start with Catalyst

=head2 L<Catalyst::Manual> - The Catalyst Manual

=head2 L<Catalyst::Component>, L<Catalyst::Controller> - Base classes for components

=head2 L<Catalyst::Engine> - Core engine

=head2 L<Catalyst::Log> - Log class.

=head2 L<Catalyst::Request> - Request object

=head2 L<Catalyst::Response> - Response object

=head2 L<Catalyst::Test> - The test suite.

=head1 PROJECT FOUNDER

sri: Sebastian Riedel <sri@cpan.org>

=head1 CONTRIBUTORS

abw: Andy Wardley

acme: Leon Brocard <leon@astray.com>

abraxxa: Alexander Hartmaier <abraxxa@cpan.org>

Andrew Bramble

Andrew Ford E<lt>A.Ford@ford-mason.co.ukE<gt>

Andrew Ruthven

andyg: Andy Grundman <andy@hybridized.org>

audreyt: Audrey Tang

bricas: Brian Cassidy <bricas@cpan.org>

Caelum: Rafael Kitover <rkitover@io.com>

chansen: Christian Hansen

chicks: Christopher Hicks

Chisel Wright C<pause@herlpacker.co.uk>

Danijel Milicevic C<me@danijel.de>

David Kamholz E<lt>dkamholz@cpan.orgE<gt>

David Naughton, C<naughton@umn.edu>

David E. Wheeler

dkubb: Dan Kubb <dan.kubb-cpan@onautopilot.com>

Drew Taylor

dwc: Daniel Westermann-Clark <danieltwc@cpan.org>

esskar: Sascha Kiefer

fireartist: Carl Franks <cfranks@cpan.org>

frew: Arthur Axel "fREW" Schmidt <frioux@gmail.com>

gabb: Danijel Milicevic

Gary Ashton Jones

Gavin Henry C<ghenry@perl.me.uk>

Geoff Richards

groditi: Guillermo Roditi <groditi@gmail.com>

hobbs: Andrew Rodland <andrew@cleverdomain.org>

ilmari: Dagfinn Ilmari Mannsåker <ilmari@ilmari.org>

jcamacho: Juan Camacho

jester: Jesse Sheidlower C<jester@panix.com>

jhannah: Jay Hannah <jay@jays.net>

Jody Belka

Johan Lindstrom

jon: Jon Schutz <jjschutz@cpan.org>

Jonathan Rockway C<< <jrockway@cpan.org> >>

Kieren Diment C<kd@totaldatasolution.com>

konobi: Scott McWhirter <konobi@cpan.org>

marcus: Marcus Ramberg <mramberg@cpan.org>

miyagawa: Tatsuhiko Miyagawa <miyagawa@bulknews.net>

mst: Matt S. Trout <mst@shadowcatsystems.co.uk>

mugwump: Sam Vilain

naughton: David Naughton

ningu: David Kamholz <dkamholz@cpan.org>

nothingmuch: Yuval Kogman <nothingmuch@woobling.org>

numa: Dan Sully <daniel@cpan.org>

obra: Jesse Vincent

omega: Andreas Marienborg

Oleg Kostyuk <cub.uanic@gmail.com>

phaylon: Robert Sedlacek <phaylon@dunkelheit.at>

rafl: Florian Ragwitz <rafl@debian.org>

random: Roland Lammel <lammel@cpan.org>

Robert Sedlacek C<< <rs@474.at> >>

sky: Arthur Bergman

t0m: Tomas Doran <bobtfish@bobtfish.net>

Ulf Edvinsson

Viljo Marrandi C<vilts@yahoo.com>

Will Hawes C<info@whawes.co.uk>

willert: Sebastian Willert <willert@cpan.org>

Yuval Kogman, C<nothingmuch@woobling.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

no Moose;

__PACKAGE__->meta->make_immutable;

1;
