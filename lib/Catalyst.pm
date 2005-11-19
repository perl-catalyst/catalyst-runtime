package Catalyst;

use strict;
use base 'Catalyst::Base';
use bytes;
use UNIVERSAL::require;
use Catalyst::Exception;
use Catalyst::Log;
use Catalyst::Request;
use Catalyst::Request::Upload;
use Catalyst::Response;
use Catalyst::Utils;
use NEXT;
use Text::SimpleTable;
use Path::Class;
use Time::HiRes qw/gettimeofday tv_interval/;
use URI;
use Scalar::Util qw/weaken/;
use attributes;

__PACKAGE__->mk_accessors(
    qw/counter request response state action stack namespace/
);

attributes->import( __PACKAGE__, \&namespace, 'lvalue' );

sub depth { scalar @{ shift->stack || [] }; }

# Laziness++
*comp = \&component;
*req  = \&request;
*res  = \&response;

# For backwards compatibility
*finalize_output = \&finalize_body;

# For statistics
our $COUNT     = 1;
our $START     = time;
our $RECURSION = 1000;
our $DETACH    = "catalyst_detach\n";

require Module::Pluggable::Fast;

# Helper script generation
our $CATALYST_SCRIPT_GEN = 19;

__PACKAGE__->mk_classdata($_)
  for qw/components arguments dispatcher engine log dispatcher_class
  engine_class context_class request_class response_class/;

__PACKAGE__->dispatcher_class('Catalyst::Dispatcher');
__PACKAGE__->engine_class('Catalyst::Engine::CGI');
__PACKAGE__->request_class('Catalyst::Request');
__PACKAGE__->response_class('Catalyst::Response');

our $VERSION = '5.57';

sub import {
    my ( $class, @arguments ) = @_;

    # We have to limit $class to Catalyst to avoid pushing Catalyst upon every
    # callers @ISA.
    return unless $class eq 'Catalyst';

    my $caller = caller(0);

    unless ( $caller->isa('Catalyst') ) {
        no strict 'refs';
        push @{"$caller\::ISA"}, $class;
    }

    $caller->arguments( [@arguments] );
    $caller->setup_home;
}

=head1 NAME

Catalyst - The Elegant MVC Web Application Framework

=head1 SYNOPSIS

    # use the helper to start a new application
    catalyst.pl MyApp

    # add models, views, controllers
    script/myapp_create.pl model Database DBIC dbi:SQLite:/path/to/db
    script/myapp_create.pl view TT TT
    script/myapp_create.pl controller Search

    # built in testserver -- use -r to restart automatically on changes
    script/myapp_server.pl

    # command line testing interface
    script/myapp_test.pl /yada

    ### in MyApp.pm
    use Catalyst qw/-Debug/; # include plugins here as well
    
    sub foo : Global { # called for /foo, /foo/1, /foo/1/2, etc.
        my ( $self, $c, @args ) = @_; # args are qw/1 2/ for /foo/1/2
        $c->stash->{template} = 'foo.tt'; # set the template
        # lookup something from db -- stash vars are passed to TT
        $c->stash->{data} = 
          MyApp::Model::Database::Foo->search( { country => $args[0] } );
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
        if ( !$c->user ) {
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
    
    # first MyApp auto is called, then Foo auto, then this
    sub auto : Private { ... }
    
    # powerful regular expression paths are also possible
    sub details : Regex('^product/(\w+)/details$') {
        my ( $self, $c ) = @_;
        # extract the (\w+) from the URI
        my $product = $c->req->snippets->[0];
    }

See L<Catalyst::Manual::Intro> for additional information.

=head1 DESCRIPTION

The key concept of Catalyst is DRY (Don't Repeat Yourself).

See L<Catalyst::Manual> for more documentation.

Catalyst plugins can be loaded by naming them as arguments to the "use
Catalyst" statement. Omit the C<Catalyst::Plugin::> prefix from the
plugin name, i.e., C<Catalyst::Plugin::My::Module> becomes
C<My::Module>.

    use Catalyst qw/My::Module/;

Special flags like C<-Debug> and C<-Engine> can also be specified as
arguments when Catalyst is loaded:

    use Catalyst qw/-Debug My::Module/;

The position of plugins and flags in the chain is important, because
they are loaded in exactly the order in which they appear.

The following flags are supported:

=head2 -Debug

Enables debug output.

=head2 -Engine

Forces Catalyst to use a specific engine. Omit the
C<Catalyst::Engine::> prefix of the engine name, i.e.:

    use Catalyst qw/-Engine=CGI/;

=head2 -Home

Forces Catalyst to use a specific home directory, e.g.:

    use Catalyst qw[-Home=/usr/sri];

=head2 -Log

Specifies log level.

=head1 METHODS

=head2 Information about the current request

=head2 $c->action

Returns a L<Catalyst::Action> object for the current action, which
stringifies to the action name. See L<Catalyst::Action>.

=head2 $c->namespace

Returns the namespace of the current action, i.e., the uri prefix
corresponding to the controller of the current action. For example:

    # in Controller::Foo::Bar
    $c->namespace; # returns 'foo/bar';

=head2 $c->request

=head2 $c->req

Returns the current L<Catalyst::Request> object. See
L<Catalyst::Request>.

=head2 Processing and response to the current request

=head2 $c->forward( $action [, \@arguments ] )

=head2 $c->forward( $class, $method, [, \@arguments ] )

Forwards processing to a private action. If you give a class name but no
method, C<process()> is called. You may also optionally pass arguments
in an arrayref. The action will receive the arguments in C<@_> and
C<$c-E<gt>req-E<gt>args>. Upon returning from the function,
C<$c-E<gt>req-E<gt>args> will be restored to the previous values.

    $c->forward('/foo');
    $c->forward('index');
    $c->forward(qw/MyApp::Model::CDBI::Foo do_stuff/);
    $c->forward('MyApp::View::TT');

=cut

sub forward { my $c = shift; $c->dispatcher->forward( $c, @_ ) }

=head2 $c->detach( $action [, \@arguments ] )

=head2 $c->detach( $class, $method, [, \@arguments ] )

The same as C<forward>, but doesn't return.

=cut

sub detach { my $c = shift; $c->dispatcher->detach( $c, @_ ) }

=head2 $c->error

=head2 $c->error($error, ...)

=head2 $c->error($arrayref)

Returns an arrayref containing error messages.  If Catalyst encounters an
error while processing a request, it stores the error in $c->error.  This
method should not be used to store non-fatal error messages.

    my @error = @{ $c->error };

Add a new error.

    $c->error('Something bad happened');

Clear errors.  You probably don't want to clear the errors unless you are
implementing a custom error screen.

    $c->error(0);

=cut

sub error {
    my $c = shift;
    if ( $_[0] ) {
        my $error = ref $_[0] eq 'ARRAY' ? $_[0] : [@_];
        push @{ $c->{error} }, @$error;
    }
    elsif ( defined $_[0] ) { $c->{error} = undef }
    return $c->{error} || [];
}

=head2 $c->response

=head2 $c->res

Returns the current L<Catalyst::Response> object.

=head2 $c->stash

Returns a hashref to the stash, which may be used to store data and pass
it between components during a request. You can also set hash keys by
passing arguments. The stash is automatically sent to the view. The
stash is cleared at the end of a request; it cannot be used for
persistent storage.

    $c->stash->{foo} = $bar;
    $c->stash( { moose => 'majestic', qux => 0 } );
    $c->stash( bar => 1, gorch => 2 ); # equivalent to passing a hashref
    
    # stash is automatically passed to the view for use in a template
    $c->forward( 'MyApp::V::TT' );

=cut

sub stash {
    my $c = shift;
    if (@_) {
        my $stash = @_ > 1 ? {@_} : $_[0];
        while ( my ( $key, $val ) = each %$stash ) {
            $c->{stash}->{$key} = $val;
        }
    }
    return $c->{stash};
}

=head2 $c->state

Contains the return value of the last executed action.

=head2 Component Accessors

=head2 $c->comp($name)

=head2 $c->component($name)

Gets a component object by name. This method is no longer recommended,
unless you want to get a specific component by full
class. C<$c-E<gt>controller>, C<$c-E<gt>model>, and C<$c-E<gt>view>
should be used instead.

=cut

sub component {
    my $c = shift;

    if (@_) {

        my $name = shift;

        my $appclass = ref $c || $c;

        my @names = (
            $name, "${appclass}::${name}",
            map { "${appclass}::${_}::${name}" }
              qw/Model M Controller C View V/
        );

        foreach my $try (@names) {

            if ( exists $c->components->{$try} ) {

                return $c->components->{$try};
            }
        }

        foreach my $component ( keys %{ $c->components } ) {

            return $c->components->{$component} if $component =~ /$name/i;
        }

    }

    return sort keys %{ $c->components };
}

=head2 $c->controller($name)

Gets a L<Catalyst::Controller> instance by name.

    $c->controller('Foo')->do_stuff;

=cut

sub controller {
    my ( $c, $name ) = @_;
    my $controller = $c->comp("Controller::$name");
    return $controller if $controller;
    return $c->comp("C::$name");
}

=head2 $c->model($name)

Gets a L<Catalyst::Model> instance by name.

    $c->model('Foo')->do_stuff;

=cut

sub model {
    my ( $c, $name ) = @_;
    my $model = $c->comp("Model::$name");
    return $model if $model;
    return $c->comp("M::$name");
}

=head2 $c->view($name)

Gets a L<Catalyst::View> instance by name.

    $c->view('Foo')->do_stuff;

=cut

sub view {
    my ( $c, $name ) = @_;
    my $view = $c->comp("View::$name");
    return $view if $view;
    return $c->comp("V::$name");
}

=head2 Class data and helper classes

=head2 $c->config

Returns or takes a hashref containing the application's configuration.

    __PACKAGE__->config({ db => 'dsn:SQLite:foo.db' });

=head2 $c->debug

Overload to enable debug messages (same as -Debug option).

=cut

sub debug { 0 }

=head2 $c->dispatcher

Returns the dispatcher instance. Stringifies to class name. See
L<Catalyst::Dispatcher>.

=head2 $c->engine

Returns the engine instance. Stringifies to the class name. See
L<Catalyst::Engine>.

=head2 $c->log

Returns the logging object instance. Unless it is already set, Catalyst
sets this up with a L<Catalyst::Log> object. To use your own log class:

    $c->log( MyLogger->new );
    $c->log->info( 'Now logging with my own logger!' );

Your log class should implement the methods described in the
L<Catalyst::Log> man page.

=cut

=head2 Utility methods

=head2 $c->path_to(@path)

Merges C<@path> with C<$c-E<gt>config-E<gt>{home}> and returns a
L<Path::Class> object.

For example:

    $c->path_to( 'db', 'sqlite.db' );

=cut

sub path_to {
    my ( $c, @path ) = @_;
    my $path = dir( $c->config->{home}, @path );
    if ( -d $path ) { return $path }
    else { return file( $c->config->{home}, @path ) }
}

=head2 $c->plugin( $name, $class, @args )

Helper method for plugins. It creates a classdata accessor/mutator and
loads and instantiates the given class.

    MyApp->plugin( 'prototype', 'HTML::Prototype' );

    $c->prototype->define_javascript_functions;

=cut

sub plugin {
    my ( $class, $name, $plugin, @args ) = @_;
    $plugin->require;

    if ( my $error = $UNIVERSAL::require::ERROR ) {
        Catalyst::Exception->throw(
            message => qq/Couldn't load instant plugin "$plugin", "$error"/ );
    }

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

    $class->setup_log( delete $flags->{log} );
    $class->setup_plugins( delete $flags->{plugins} );
    $class->setup_dispatcher( delete $flags->{dispatcher} );
    $class->setup_engine( delete $flags->{engine} );
    $class->setup_home( delete $flags->{home} );

    for my $flag ( sort keys %{$flags} ) {

        if ( my $code = $class->can( 'setup_' . $flag ) ) {
            &$code( $class, delete $flags->{$flag} );
        }
        else {
            $class->log->warn(qq/Unknown flag "$flag"/);
        }
    }

    $class->log->warn(
        <<"EOF") if ( $ENV{CATALYST_SCRIPT_GEN} && ( $ENV{CATALYST_SCRIPT_GEN} < $Catalyst::CATALYST_SCRIPT_GEN ) );
You are running an old script!

  Please update by running (this will overwrite existing files):
    catalyst.pl -force -scripts $class

  or (this will not overwrite existing files):
    catalyst.pl -scripts $class
EOF

    if ( $class->debug ) {

        my @plugins = ();

        {
            no strict 'refs';
            @plugins = grep { /^Catalyst::Plugin/ } @{"$class\::ISA"};
        }

        if (@plugins) {
            my $t = Text::SimpleTable->new(76);
            $t->row($_) for @plugins;
            $class->log->debug( "Loaded plugins:\n" . $t->draw );
        }

        my $dispatcher = $class->dispatcher;
        my $engine     = $class->engine;
        my $home       = $class->config->{home};

        $class->log->debug(qq/Loaded dispatcher "$dispatcher"/);
        $class->log->debug(qq/Loaded engine "$engine"/);

        $home
          ? ( -d $home )
          ? $class->log->debug(qq/Found home "$home"/)
          : $class->log->debug(qq/Home "$home" doesn't exist/)
          : $class->log->debug(q/Couldn't find home/);
    }

    # Call plugins setup
    {
        no warnings qw/redefine/;
        local *setup = sub { };
        $class->setup;
    }

    # Initialize our data structure
    $class->components( {} );

    $class->setup_components;

    if ( $class->debug ) {
        my $t = Text::SimpleTable->new( [ 65, 'Class' ], [ 8, 'Type' ] );
        for my $comp ( sort keys %{ $class->components } ) {
            my $type = ref $class->components->{$comp} ? 'instance' : 'class';
            $t->row( $comp, $type );
        }
        $class->log->debug( "Loaded components:\n" . $t->draw )
          if ( keys %{ $class->components } );
    }

    # Add our self to components, since we are also a component
    $class->components->{$class} = $class;

    $class->setup_actions;

    if ( $class->debug ) {
        my $name = $class->config->{name} || 'Application';
        $class->log->info("$name powered by Catalyst $Catalyst::VERSION");
    }
    $class->log->_flush() if $class->log->can('_flush');
}

=head2 $c->uri_for( $path, [ @args ] )

Merges path with C<$c-E<gt>request-E<gt>base> for absolute uri's and
with C<$c-E<gt>namespace> for relative uri's, then returns a
normalized L<URI> object. If any args are passed, they are added at the
end of the path.

=cut

sub uri_for {
    my ( $c, $path, @args ) = @_;
    my $base     = $c->request->base->clone;
    my $basepath = $base->path;
    $basepath =~ s/\/$//;
    $basepath .= '/';
    my $namespace = $c->namespace;

    # massage namespace, empty if absolute path
    $namespace =~ s/^\///;
    $namespace .= '/' if $namespace;
    $path ||= '';
    $namespace = '' if $path =~ /^\//;
    $path =~ s/^\///;

    # join args with '/', or a blank string
    my $args = ( scalar @args ? '/' . join( '/', @args ) : '' );
    $args =~ s/^\/// unless $path;
    my $res =
      URI->new_abs( URI->new_abs( "$path$args", "$basepath$namespace" ), $base )
      ->canonical;
    $res;
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
                -moz-border-radius: 10px;
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
                -moz-border-radius: 10px;
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
                 <p>Welcome to the wonderful world of Catalyst.
                    This <a href="http://en.wikipedia.org/wiki/MVC">MVC</a>
                    framework will make web development something you had
                    never expected it to be: Fun, rewarding and quick.</p>
                 <h2>What to do now?</h2>
                 <p>That really depends  on what <b>you</b> want to do.
                    We do, however, provide you with a few starting points.</p>
                 <p>If you want to jump right into web development with Catalyst
                    you might want to check out the documentation.</p>
                 <pre><code>perldoc <a href="http://cpansearch.perl.org/dist/Catalyst/lib/Catalyst/Manual/Intro.pod">Catalyst::Manual::Intro</a>
perldoc <a href="http://cpansearch.perl.org/dist/Catalyst/lib/Catalyst/Manual.pod">Catalyst::Manual</a></code></pre>
                 <h2>What to do next?</h2>
                 <p>Next it's time to write an actual application. Use the
                    helper scripts to generate <a href="http://cpansearch.perl.org/search?query=Catalyst%3A%3AController%3A%3A&amp;mode=all">controllers</a>,
                    <a href="http://cpansearch.perl.org/search?query=Catalyst%3A%3AModel%3A%3A&amp;mode=all">models</a> and
                    <a href="http://cpansearch.perl.org/search?query=Catalyst%3A%3AView%3A%3A&amp;mode=all">views</a>,
                    they can save you a lot of work.</p>
                    <pre><code>script/${prefix}_create.pl -help</code></pre>
                    <p>Also, be sure to check out the vast and growing
                    collection of <a href="http://cpansearch.perl.org/search?query=Catalyst%3A%3APlugin%3A%3A&amp;mode=all">plugins for Catalyst on CPAN</a>,
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
                         <a href="http://lists.rawmode.org/mailman/listinfo/catalyst">Mailing-List</a>
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

=head2 $c->counter

Returns a hashref containing coderefs and execution counts (needed for
deep recursion detection).

=head2 $c->depth

Returns the number of actions on the current internal execution stack.

=head2 $c->dispatch

Dispatches a request to actions.

=cut

sub dispatch { my $c = shift; $c->dispatcher->dispatch( $c, @_ ) }

=head2 $c->dispatcher_class

Returns or sets the dispatcher class.

=head2 $c->dump_these

Returns a list of 2-element array references (name, structure) pairs
that will be dumped on the error page in debug mode.

=cut

sub dump_these {
    my $c = shift;
    [ Request => $c->req ], [ Response => $c->res ], [ Stash => $c->stash ],;
}

=head2 $c->engine_class

Returns or sets the engine class.

=head2 $c->execute( $class, $coderef )

Execute a coderef in given class and catch exceptions. Errors are available
via $c->error.

=cut

sub execute {
    my ( $c, $class, $code ) = @_;
    $class = $c->components->{$class} || $class;
    $c->state(0);

    my $callsub =
        ( caller(0) )[0]->isa('Catalyst::Action')
      ? ( caller(2) )[3]
      : ( caller(1) )[3];

    my $action = '';
    if ( $c->debug ) {
        $action = "$code";
        $action = "/$action" unless $action =~ /\-\>/;
        $c->counter->{"$code"}++;

        if ( $c->counter->{"$code"} > $RECURSION ) {
            my $error = qq/Deep recursion detected in "$action"/;
            $c->log->error($error);
            $c->error($error);
            $c->state(0);
            return $c->state;
        }

        $action = "-> $action" if $callsub =~ /forward$/;
    }
    push( @{ $c->stack }, $code );
    my $elapsed = 0;
    my $start   = 0;
    $start = [gettimeofday] if $c->debug;
    eval { $c->state( &$code( $class, $c, @{ $c->req->args } ) || 0 ) };
    $elapsed = tv_interval($start) if $c->debug;

    if ( $c->debug ) {
        unless ( ( $code->name =~ /^_.*/ )
            && ( !$c->config->{show_internal_actions} ) )
        {
            push @{ $c->{stats} }, [ $action, sprintf( '%fs', $elapsed ) ];
        }
    }
    pop( @{ $c->stack } );

    if ( my $error = $@ ) {

        if ( $error eq $DETACH ) { die $DETACH if $c->depth > 1 }
        else {
            unless ( ref $error ) {
                chomp $error;
                $error = qq/Caught exception "$error"/;
            }
            $c->error($error);
            $c->state(0);
        }
    }
    return $c->state;
}

=head2 $c->finalize

Finalizes the request.

=cut

sub finalize {
    my $c = shift;

    for my $error ( @{ $c->error } ) {
        $c->log->error($error);
    }

    $c->finalize_uploads;

    # Error
    if ( $#{ $c->error } >= 0 ) {
        $c->finalize_error;
    }

    $c->finalize_headers;

    # HEAD request
    if ( $c->request->method eq 'HEAD' ) {
        $c->response->body('');
    }

    $c->finalize_body;

    return $c->response->status;
}

=head2 $c->finalize_body

Finalizes body.

=cut

sub finalize_body { my $c = shift; $c->engine->finalize_body( $c, @_ ) }

=head2 $c->finalize_cookies

Finalizes cookies.

=cut

sub finalize_cookies { my $c = shift; $c->engine->finalize_cookies( $c, @_ ) }

=head2 $c->finalize_error

Finalizes error.

=cut

sub finalize_error { my $c = shift; $c->engine->finalize_error( $c, @_ ) }

=head2 $c->finalize_headers

Finalizes headers.

=cut

sub finalize_headers {
    my $c = shift;

    # Check if we already finalized headers
    return if $c->response->{_finalized_headers};

    # Handle redirects
    if ( my $location = $c->response->redirect ) {
        $c->log->debug(qq/Redirecting to "$location"/) if $c->debug;
        $c->response->header( Location => $location );
    }

    # Content-Length
    if ( $c->response->body && !$c->response->content_length ) {
        $c->response->content_length( bytes::length( $c->response->body ) );
    }

    # Errors
    if ( $c->response->status =~ /^(1\d\d|[23]04)$/ ) {
        $c->response->headers->remove_header("Content-Length");
        $c->response->body('');
    }

    $c->finalize_cookies;

    $c->engine->finalize_headers( $c, @_ );

    # Done
    $c->response->{_finalized_headers} = 1;
}

=head2 $c->finalize_output

An alias for finalize_body.

=head2 $c->finalize_read

Finalizes the input after reading is complete.

=cut

sub finalize_read { my $c = shift; $c->engine->finalize_read( $c, @_ ) }

=head2 $c->finalize_uploads

Finalizes uploads. Cleans up any temporary files.

=cut

sub finalize_uploads { my $c = shift; $c->engine->finalize_uploads( $c, @_ ) }

=head2 $c->get_action( $action, $namespace )

Gets an action in a given namespace.

=cut

sub get_action { my $c = shift; $c->dispatcher->get_action(@_) }

=head2 $c->get_actions( $action, $namespace )

Gets all actions of a given name in a namespace and all parent
namespaces.

=cut

sub get_actions { my $c = shift; $c->dispatcher->get_actions( $c, @_ ) }

=head2 handle_request( $class, @arguments )

Called to handle each HTTP request.

=cut

sub handle_request {
    my ( $class, @arguments ) = @_;

    # Always expect worst case!
    my $status = -1;
    eval {
        my @stats = ();

        my $handler = sub {
            my $c = $class->prepare(@arguments);
            $c->{stats} = \@stats;
            $c->dispatch;
            return $c->finalize;
        };

        if ( $class->debug ) {
            my $start = [gettimeofday];
            $status = &$handler;
            my $elapsed = tv_interval $start;
            $elapsed = sprintf '%f', $elapsed;
            my $av = sprintf '%.3f',
              ( $elapsed == 0 ? '??' : ( 1 / $elapsed ) );
            my $t = Text::SimpleTable->new( [ 64, 'Action' ], [ 9, 'Time' ] );

            for my $stat (@stats) { $t->row( $stat->[0], $stat->[1] ) }
            $class->log->info(
                "Request took ${elapsed}s ($av/s)\n" . $t->draw );
        }
        else { $status = &$handler }

    };

    if ( my $error = $@ ) {
        chomp $error;
        $class->log->error(qq/Caught exception in engine "$error"/);
    }

    $COUNT++;
    $class->log->_flush() if $class->log->can('_flush');
    return $status;
}

=head2 $c->prepare( @arguments )

Creates a Catalyst context from an engine-specific request (Apache, CGI,
etc.).

=cut

sub prepare {
    my ( $class, @arguments ) = @_;

    $class->context_class( ref $class || $class ) unless $class->context_class;
    my $c = $class->context_class->new(
        {
            counter => {},
            stack   => [],
            request => $class->request_class->new(
                {
                    arguments        => [],
                    body_parameters  => {},
                    cookies          => {},
                    headers          => HTTP::Headers->new,
                    parameters       => {},
                    query_parameters => {},
                    secure           => 0,
                    snippets         => [],
                    uploads          => {}
                }
            ),
            response => $class->response_class->new(
                {
                    body    => '',
                    cookies => {},
                    headers => HTTP::Headers->new(),
                    status  => 200
                }
            ),
            stash => {},
            state => 0
        }
    );

    # For on-demand data
    $c->request->{_context}  = $c;
    $c->response->{_context} = $c;
    weaken( $c->request->{_context} );
    weaken( $c->response->{_context} );

    if ( $c->debug ) {
        my $secs = time - $START || 1;
        my $av = sprintf '%.3f', $COUNT / $secs;
        $c->log->debug('**********************************');
        $c->log->debug("* Request $COUNT ($av/s) [$$]");
        $c->log->debug('**********************************');
        $c->res->headers->header( 'X-Catalyst' => $Catalyst::VERSION );
    }

    $c->prepare_request(@arguments);
    $c->prepare_connection;
    $c->prepare_query_parameters;
    $c->prepare_headers;
    $c->prepare_cookies;
    $c->prepare_path;

    # On-demand parsing
    $c->prepare_body unless $c->config->{parse_on_demand};

    my $method  = $c->req->method  || '';
    my $path    = $c->req->path    || '';
    my $address = $c->req->address || '';

    $c->log->debug(qq/"$method" request for "$path" from "$address"/)
      if $c->debug;

    $c->prepare_action;

    return $c;
}

=head2 $c->prepare_action

Prepares action.

=cut

sub prepare_action { my $c = shift; $c->dispatcher->prepare_action( $c, @_ ) }

=head2 $c->prepare_body

Prepares message body.

=cut

sub prepare_body {
    my $c = shift;

    # Do we run for the first time?
    return if defined $c->request->{_body};

    # Initialize on-demand data
    $c->engine->prepare_body( $c, @_ );
    $c->prepare_parameters;
    $c->prepare_uploads;

    if ( $c->debug && keys %{ $c->req->body_parameters } ) {
        my $t = Text::SimpleTable->new( [ 37, 'Key' ], [ 36, 'Value' ] );
        for my $key ( sort keys %{ $c->req->body_parameters } ) {
            my $param = $c->req->body_parameters->{$key};
            my $value = defined($param) ? $param : '';
            $t->row( $key,
                ref $value eq 'ARRAY' ? ( join ', ', @$value ) : $value );
        }
        $c->log->debug( "Body Parameters are:\n" . $t->draw );
    }
}

=head2 $c->prepare_body_chunk( $chunk )

Prepares a chunk of data before sending it to L<HTTP::Body>.

=cut

sub prepare_body_chunk {
    my $c = shift;
    $c->engine->prepare_body_chunk( $c, @_ );
}

=head2 $c->prepare_body_parameters

Prepares body parameters.

=cut

sub prepare_body_parameters {
    my $c = shift;
    $c->engine->prepare_body_parameters( $c, @_ );
}

=head2 $c->prepare_connection

Prepares connection.

=cut

sub prepare_connection {
    my $c = shift;
    $c->engine->prepare_connection( $c, @_ );
}

=head2 $c->prepare_cookies

Prepares cookies.

=cut

sub prepare_cookies { my $c = shift; $c->engine->prepare_cookies( $c, @_ ) }

=head2 $c->prepare_headers

Prepares headers.

=cut

sub prepare_headers { my $c = shift; $c->engine->prepare_headers( $c, @_ ) }

=head2 $c->prepare_parameters

Prepares parameters.

=cut

sub prepare_parameters {
    my $c = shift;
    $c->prepare_body_parameters;
    $c->engine->prepare_parameters( $c, @_ );
}

=head2 $c->prepare_path

Prepares path and base.

=cut

sub prepare_path { my $c = shift; $c->engine->prepare_path( $c, @_ ) }

=head2 $c->prepare_query_parameters

Prepares query parameters.

=cut

sub prepare_query_parameters {
    my $c = shift;

    $c->engine->prepare_query_parameters( $c, @_ );

    if ( $c->debug && keys %{ $c->request->query_parameters } ) {
        my $t = Text::SimpleTable->new( [ 37, 'Key' ], [ 36, 'Value' ] );
        for my $key ( sort keys %{ $c->req->query_parameters } ) {
            my $param = $c->req->query_parameters->{$key};
            my $value = defined($param) ? $param : '';
            $t->row( $key,
                ref $value eq 'ARRAY' ? ( join ', ', @$value ) : $value );
        }
        $c->log->debug( "Query Parameters are:\n" . $t->draw );
    }
}

=head2 $c->prepare_read

Prepares the input for reading.

=cut

sub prepare_read { my $c = shift; $c->engine->prepare_read( $c, @_ ) }

=head2 $c->prepare_request

Prepares the engine request.

=cut

sub prepare_request { my $c = shift; $c->engine->prepare_request( $c, @_ ) }

=head2 $c->prepare_uploads

Prepares uploads.

=cut

sub prepare_uploads {
    my $c = shift;

    $c->engine->prepare_uploads( $c, @_ );

    if ( $c->debug && keys %{ $c->request->uploads } ) {
        my $t = Text::SimpleTable->new(
            [ 12, 'Key' ],
            [ 28, 'Filename' ],
            [ 18, 'Type' ],
            [ 9,  'Size' ]
        );
        for my $key ( sort keys %{ $c->request->uploads } ) {
            my $upload = $c->request->uploads->{$key};
            for my $u ( ref $upload eq 'ARRAY' ? @{$upload} : ($upload) ) {
                $t->row( $key, $u->filename, $u->type, $u->size );
            }
        }
        $c->log->debug( "File Uploads are:\n" . $t->draw );
    }
}

=head2 $c->prepare_write

Prepares the output for writing.

=cut

sub prepare_write { my $c = shift; $c->engine->prepare_write( $c, @_ ) }

=head2 $c->request_class

Returns or sets the request class.

=head2 $c->response_class

Returns or sets the response class.

=head2 $c->read( [$maxlength] )

Reads a chunk of data from the request body. This method is designed to
be used in a while loop, reading C<$maxlength> bytes on every call.
C<$maxlength> defaults to the size of the request if not specified.

You have to set C<MyApp-E<gt>config-E<gt>{parse_on_demand}> to use this
directly.

=cut

sub read { my $c = shift; return $c->engine->read( $c, @_ ) }

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

Sets up components.

=cut

sub setup_components {
    my $class = shift;

    my $callback = sub {
        my ( $component, $context ) = @_;

        unless ( $component->isa('Catalyst::Component') ) {
            return $component;
        }

        my $suffix = Catalyst::Utils::class2classsuffix($component);
        my $config = $class->config->{$suffix} || {};

        my $instance;

        eval { $instance = $component->new( $context, $config ); };

        if ( my $error = $@ ) {

            chomp $error;

            Catalyst::Exception->throw( message =>
                  qq/Couldn't instantiate component "$component", "$error"/ );
        }

        Catalyst::Exception->throw( message =>
qq/Couldn't instantiate component "$component", "new() didn't return a object"/
          )
          unless ref $instance;
        return $instance;
    };

    eval "package $class;\n" . q!Module::Pluggable::Fast->import(
            name   => '_catalyst_components',
            search => [
                "$class\::Controller", "$class\::C",
                "$class\::Model",      "$class\::M",
                "$class\::View",       "$class\::V"
            ],
            callback => $callback
        );
    !;

    if ( my $error = $@ ) {

        chomp $error;

        Catalyst::Exception->throw(
            message => qq/Couldn't load components "$error"/ );
    }

    for my $component ( $class->_catalyst_components($class) ) {
        $class->components->{ ref $component || $component } = $component;
    }
}

=head2 $c->setup_dispatcher

Sets up dispatcher.

=cut

sub setup_dispatcher {
    my ( $class, $dispatcher ) = @_;

    if ($dispatcher) {
        $dispatcher = 'Catalyst::Dispatcher::' . $dispatcher;
    }

    if ( $ENV{CATALYST_DISPATCHER} ) {
        $dispatcher = 'Catalyst::Dispatcher::' . $ENV{CATALYST_DISPATCHER};
    }

    if ( $ENV{ uc($class) . '_DISPATCHER' } ) {
        $dispatcher =
          'Catalyst::Dispatcher::' . $ENV{ uc($class) . '_DISPATCHER' };
    }

    unless ($dispatcher) {
        $dispatcher = $class->dispatcher_class;
    }

    $dispatcher->require;

    if ($@) {
        Catalyst::Exception->throw(
            message => qq/Couldn't load dispatcher "$dispatcher", "$@"/ );
    }

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

    if ( $ENV{CATALYST_ENGINE} ) {
        $engine = 'Catalyst::Engine::' . $ENV{CATALYST_ENGINE};
    }

    if ( $ENV{ uc($class) . '_ENGINE' } ) {
        $engine = 'Catalyst::Engine::' . $ENV{ uc($class) . '_ENGINE' };
    }

    if ( !$engine && $ENV{MOD_PERL} ) {

        # create the apache method
        {
            no strict 'refs';
            *{"$class\::apache"} = sub { shift->engine->apache };
        }

        my ( $software, $version ) =
          $ENV{MOD_PERL} =~ /^(\S+)\/(\d+(?:[\.\_]\d+)+)/;

        $version =~ s/_//g;
        $version =~ s/(\.[^.]+)\./$1/g;

        if ( $software eq 'mod_perl' ) {

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

    $engine->require;

    if ($@) {
        Catalyst::Exception->throw( message =>
qq/Couldn't load engine "$engine" (maybe you forgot to install it?), "$@"/
        );
    }

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

    if ( $ENV{CATALYST_HOME} ) {
        $home = $ENV{CATALYST_HOME};
    }

    if ( $ENV{ uc($class) . '_HOME' } ) {
        $home = $ENV{ uc($class) . '_HOME' };
    }

    unless ($home) {
        $home = Catalyst::Utils::home($class);
    }

    if ($home) {
        $class->config->{home} ||= $home;
        $class->config->{root} ||= dir($home)->subdir('root');
    }
}

=head2 $c->setup_log

Sets up log.

=cut

sub setup_log {
    my ( $class, $debug ) = @_;

    unless ( $class->log ) {
        $class->log( Catalyst::Log->new );
    }

    my $app_flag = Catalyst::Utils::class2env($class) . '_DEBUG';

    if (
          ( defined( $ENV{CATALYST_DEBUG} ) || defined( $ENV{$app_flag} ) )
        ? ( $ENV{CATALYST_DEBUG} || $ENV{$app_flag} )
        : $debug
      )
    {
        no strict 'refs';
        *{"$class\::debug"} = sub { 1 };
        $class->log->debug('Debug messages enabled');
    }
}

=head2 $c->setup_plugins

Sets up plugins.

=cut

sub setup_plugins {
    my ( $class, $plugins ) = @_;

    $plugins ||= [];
    for my $plugin ( reverse @$plugins ) {

        $plugin = "Catalyst::Plugin::$plugin";

        $plugin->require;

        if ($@) {
            Catalyst::Exception->throw(
                message => qq/Couldn't load plugin "$plugin", "$@"/ );
        }

        {
            no strict 'refs';
            unshift @{"$class\::ISA"}, $plugin;
        }
    }
}

=head2 $c->stack

Returns the stack.

=head2 $c->write( $data )

Writes $data to the output stream. When using this method directly, you
will need to manually set the C<Content-Length> header to the length of
your output data, if known.

=cut

sub write {
    my $c = shift;

    # Finalize headers if someone manually writes output
    $c->finalize_headers;

    return $c->engine->write( $c, @_ );
}

=head2 version

Returns the Catalyst version number. Mostly useful for "powered by"
messages in template systems.

=cut

sub version { return $Catalyst::VERSION }

=head1 INTERNAL ACTIONS

Catalyst uses internal actions like C<_DISPATCH>, C<_BEGIN>, C<_AUTO>,
C<_ACTION>, and C<_END>. These are by default not shown in the private
action table, but you can make them visible with a config parameter.

    MyApp->config->{show_internal_actions} = 1;

=head1 CASE SENSITIVITY

By default Catalyst is not case sensitive, so C<MyApp::C::FOO::Bar> is
mapped to C</foo/bar>. You can activate case sensitivity with a config
parameter.

    MyApp->config->{case_sensitive} = 1;

This causes C<MyApp::C::Foo::Bar> to map to C</Foo/Bar>.

=head1 ON-DEMAND PARSER

The request body is usually parsed at the beginning of a request,
but if you want to handle input yourself or speed things up a bit,
you can enable on-demand parsing with a config parameter.

    MyApp->config->{parse_on_demand} = 1;
    
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

Obviously, your web server must support these headers for this to work.

In a more complex server farm environment where you may have your
frontend proxy server(s) on different machines, you will need to set a
configuration option to tell Catalyst to read the proxied data from the
headers.

    MyApp->config->{using_frontend_proxy} = 1;
    
If you do not wish to use the proxy support at all, you may set:

    MyApp->config->{ignore_frontend_proxy} = 1;

=head1 THREAD SAFETY

Catalyst has been tested under Apache 2's threading mpm_worker, mpm_winnt,
and the standalone forking HTTP server on Windows. We believe the Catalyst
core to be thread-safe.

If you plan to operate in a threaded environment, remember that all other
modules you are using must also be thread-safe. Some modules, most notably
L<DBD::SQLite>, are not thread-safe.

=head1 SUPPORT

IRC:

    Join #catalyst on irc.perl.org.

Mailing Lists:

    http://lists.rawmode.org/mailman/listinfo/catalyst
    http://lists.rawmode.org/mailman/listinfo/catalyst-dev

Web:

    http://catalyst.perl.org

Wiki:

    http://dev.catalyst.perl.org

=head1 SEE ALSO

=head2 L<Catalyst::Manual> - The Catalyst Manual

=head2 L<Catalyst::Component>, L<Catalyst::Base> - Base classes for components

=head2 L<Catalyst::Engine> - Core engine

=head2 L<Catalyst::Log> - Log class.

=head2 L<Catalyst::Request> - Request object

=head2 L<Catalyst::Response> - Response object

=head2 L<Catalyst::Test> - The test suite.

=head1 CREDITS

Andy Grundman

Andy Wardley

Andreas Marienborg

Andrew Bramble

Andrew Ford

Andrew Ruthven

Arthur Bergman

Autrijus Tang

Brian Cassidy

Christian Hansen

Christopher Hicks

Dan Sully

Danijel Milicevic

David Kamholz

David Naughton

Drew Taylor

Gary Ashton Jones

Geoff Richards

Jesse Sheidlower

Jesse Vincent

Jody Belka

Johan Lindstrom

Juan Camacho

Leon Brocard

Marcus Ramberg

Matt S Trout

Robert Sedlacek

Sam Vilain

Sascha Kiefer

Tatsuhiko Miyagawa

Ulf Edvinsson

Yuval Kogman

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
