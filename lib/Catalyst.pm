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
use Text::ASCIITable;
use Path::Class;
use Time::HiRes qw/gettimeofday tv_interval/;
use URI;
use Scalar::Util qw/weaken/;

__PACKAGE__->mk_accessors(
    qw/counter depth request response state action namespace/
);

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
our $CATALYST_SCRIPT_GEN = 8;

__PACKAGE__->mk_classdata($_)
  for qw/components arguments dispatcher engine log/;

our $VERSION = '5.49_02';

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
    cd MyApp

    # add models, views, controllers
    script/myapp_create.pl model Something
    script/myapp_create.pl view Stuff
    script/myapp_create.pl controller Yada

    # built in testserver
    script/myapp_server.pl

    # command line interface
    script/myapp_test.pl /yada


    use Catalyst;

    use Catalyst qw/My::Module My::OtherModule/;

    use Catalyst '-Debug';

    use Catalyst qw/-Debug -Engine=CGI/;

    sub default : Private { $_[1]->res->output('Hello') } );

    sub index : Path('/index.html') {
        my ( $self, $c ) = @_;
        $c->res->output('Hello');
        $c->forward('foo');
    }

    sub product : Regex('^product[_]*(\d*).html$') {
        my ( $self, $c ) = @_;
        $c->stash->{template} = 'product.tt';
        $c->stash->{product} = $c->req->snippets->[0];
    }

See also L<Catalyst::Manual::Intro>

=head1 DESCRIPTION

The key concept of Catalyst is DRY (Don't Repeat Yourself).

See L<Catalyst::Manual> for more documentation.

Catalyst plugins can be loaded by naming them as arguments to the "use Catalyst" statement.
Omit the C<Catalyst::Plugin::> prefix from the plugin name,
so C<Catalyst::Plugin::My::Module> becomes C<My::Module>.

    use Catalyst 'My::Module';

Special flags like -Debug and -Engine can also be specified as arguments when
Catalyst is loaded:

    use Catalyst qw/-Debug My::Module/;

The position of plugins and flags in the chain is important, because they are
loaded in exactly the order that they appear.

The following flags are supported:

=over 4

=item -Debug

enables debug output, i.e.:

    use Catalyst '-Debug';

this is equivalent to:

    use Catalyst;
    sub debug { 1 }

=item -Dispatcher

Force Catalyst to use a specific dispatcher.

=item -Engine

Force Catalyst to use a specific engine.
Omit the C<Catalyst::Engine::> prefix of the engine name, i.e.:

    use Catalyst '-Engine=CGI';

=item -Home

Force Catalyst to use a specific home directory.

=item -Log

Specify log level.

=back

=head1 METHODS

=over 4

=item $c->action

Accessor for the current action

=item $c->comp($name)

=item $c->component($name)

Get a component object by name.

    $c->comp('MyApp::Model::MyModel')->do_stuff;

=cut

sub component {
    my $c = shift;

    if (@_) {

        my $name = shift;

        my $appclass = ref $c || $c;

        my @names = (
            $name, "${appclass}::${name}",
            map { "${appclass}::${_}::${name}" } qw/M V C/
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

=item config

Returns a hashref containing your applications settings.

=item debug

Overload to enable debug messages.

=cut

sub debug { 0 }

=item $c->detach( $command [, \@arguments ] )

Like C<forward> but doesn't return.

=cut

sub detach { my $c = shift; $c->dispatcher->detach( $c, @_ ) }

=item $c->dispatcher

Contains the dispatcher instance.
Stringifies to class.

=item $c->forward( $command [, \@arguments ] )

Forward processing to a private action or a method from a class.
If you define a class without method it will default to process().
also takes an optional arrayref containing arguments to be passed
to the new function. $c->req->args will be reset upon returning 
from the function.

    $c->forward('/foo');
    $c->forward('index');
    $c->forward(qw/MyApp::Model::CDBI::Foo do_stuff/);
    $c->forward('MyApp::View::TT');

=cut

sub forward { my $c = shift; $c->dispatcher->forward( $c, @_ ) }

=item $c->namespace

Accessor to the namespace of the current action

=item $c->path_to(@path)

Merges C<@path> with $c->config->{home} and returns a L<Path::Class> object.

For example:

    $c->path_to( 'db', 'sqlite.db' );

=cut

sub path_to {
    my ( $c, @path ) = @_;
    my $path = dir( $c->config->{home}, @path );
    if ( -d $path ) { return $path }
    else { return file( $c->config->{home}, @path ) }
}

=item $c->setup

Setup.

    $c->setup;

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

    $class->log->warn( "You are running an old helper script! "
          . "Please update your scripts by regenerating the "
          . "application and copying over the new scripts." )
      if ( $ENV{CATALYST_SCRIPT_GEN}
        && ( $ENV{CATALYST_SCRIPT_GEN} < $Catalyst::CATALYST_SCRIPT_GEN ) );

    if ( $class->debug ) {

        my @plugins = ();

        {
            no strict 'refs';
            @plugins = grep { /^Catalyst::Plugin/ } @{"$class\::ISA"};
        }

        if (@plugins) {
            my $t = Text::ASCIITable->new;
            $t->setOptions( 'hide_HeadRow',  1 );
            $t->setOptions( 'hide_HeadLine', 1 );
            $t->setCols('Class');
            $t->setColWidth( 'Class', 75, 1 );
            $t->addRow($_) for @plugins;
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
        my $t = Text::ASCIITable->new;
        $t->setOptions( 'hide_HeadRow',  1 );
        $t->setOptions( 'hide_HeadLine', 1 );
        $t->setCols('Class');
        $t->setColWidth( 'Class', 75, 1 );
        $t->addRow($_) for sort keys %{ $class->components };
        $class->log->debug( "Loaded components:\n" . $t->draw )
          if ( @{ $t->{tbl_rows} } );
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

=item $c->uri_for($path,[@args])

Merges path with $c->request->base for absolute uri's and with
$c->request->match for relative uri's, then returns a normalized
L<URI> object. If any args are passed, they are added at the end
of the path.

=cut

sub uri_for {
    my ( $c, $path, @args ) = @_;
    my $base     = $c->request->base->clone;
    my $basepath = $base->path;
    $basepath =~ s/\/$//;
    $basepath .= '/';
    my $match = $c->request->match;

    # massage match, empty if absolute path
    $match =~ s/^\///;
    $match .= '/' if $match;
    $match = '' if $path =~ /^\//;
    $path =~ s/^\///;

    # join args with '/', or a blank string
    my $args = ( scalar @args ? '/' . join( '/', @args ) : '' );
    return URI->new_abs( URI->new_abs( "$path$args", "$basepath$match" ),
        $base )->canonical;
}

=item $c->error

=item $c->error($error, ...)

=item $c->error($arrayref)

Returns an arrayref containing error messages.

    my @error = @{ $c->error };

Add a new error.

    $c->error('Something bad happened');

Clean errors.

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

=item $c->engine

Contains the engine instance.
Stringifies to the class.

=item $c->log

Contains the logging object.  Unless it is already set Catalyst sets this up with a
C<Catalyst::Log> object.  To use your own log class:

    $c->log( MyLogger->new );
    $c->log->info("now logging with my own logger!");

Your log class should implement the methods described in the C<Catalyst::Log>
man page.

=item $c->plugin( $name, $class, @args )

Instant plugins for Catalyst.
Classdata accessor/mutator will be created, class loaded and instantiated.

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

=item $c->request

=item $c->req

Returns a C<Catalyst::Request> object.

    my $req = $c->req;

=item $c->response

=item $c->res

Returns a C<Catalyst::Response> object.

    my $res = $c->res;

=item $c->state

Contains the return value of the last executed action.

=item $c->stash

Returns a hashref containing all your data.

    print $c->stash->{foo};

Keys may be set in the stash by assigning to the hash reference, or by passing
either a single hash reference or a list of key/value pairs as arguments.

For example:

    $c->stash->{foo} ||= 'yada';
    $c->stash( { moose => 'majestic', qux => 0 } );
    $c->stash( bar => 1, gorch => 2 );

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

=item $c->welcome_message

Returns the Catalyst welcome HTML page.

=cut

sub welcome_message {
    my $c      = shift;
    my $name   = $c->config->{name};
    my $logo   = $c->uri_for('/static/images/catalyst_logo.png');
    my $prefix = Catalyst::Utils::appprefix( ref $c );
    return <<"EOF";
<html>
    <head>
        <title>$name on Catalyst $VERSION</title>
        <style type="text/css">
            body {
                text-align: center;
                padding-left: 50%;
                color: #000;
                background-color: #eee;
            }
            div#content {
                width: 640px;
                margin-left: -320px;
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
            b#appname {
                font-size: 1.6em;
            }
        </style>
    </head>
    <body>
        <div id="content">
            <div id="topbar">
                <h1><b id="appname">$name</b> on <a href="http://catalyst.perl.org">Catalyst</a>
                    $VERSION</h1>
             </div>
             <div id="answers">
                 <p>
                 <img src="$logo"/>
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
                    helper scripts to generate <a href="http://cpansearch.perl.org/search?query=Catalyst%3A%3AController%3A%3A&mode=all">controllers</a>,
                    <a href="http://cpansearch.perl.org/search?query=Catalyst%3A%3AModel%3A%3A&mode=all">models</a> and
                    <a href="http://cpansearch.perl.org/search?query=Catalyst%3A%3AView%3A%3A&mode=all">views</a>,
                    they can save you a lot of work.</p>
                    <pre><code>script/${prefix}_create.pl -help</code></pre>
                    <p>Also, be sure to check out the vast and growing
                    collection of <a href="http://cpansearch.perl.org/search?query=Catalyst%3A%3APlugin%3A%3A&mode=all">plugins for Catalyst on CPAN</a>,
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

=back

=head1 INTERNAL METHODS

=over 4

=item $c->benchmark($coderef)

Takes a coderef with arguments and returns elapsed time as float.

    my ( $elapsed, $status ) = $c->benchmark( sub { return 1 } );
    $c->log->info( sprintf "Processing took %f seconds", $elapsed );

=cut

sub benchmark {
    my $c       = shift;
    my $code    = shift;
    my $time    = [gettimeofday];
    my @return  = &$code(@_);
    my $elapsed = tv_interval $time;
    return wantarray ? ( $elapsed, @return ) : $elapsed;
}

=item $c->components

Contains the components.

=item $c->counter

Returns a hashref containing coderefs and execution counts.
(Needed for deep recursion detection) 

=item $c->depth

Returns the actual forward depth.

=item $c->dispatch

Dispatch request to actions.

=cut

sub dispatch { my $c = shift; $c->dispatcher->dispatch( $c, @_ ) }

=item $c->execute($class, $coderef)

Execute a coderef in given class and catch exceptions.
Errors are available via $c->error.

=cut

sub execute {
    my ( $c, $class, $code ) = @_;
    $class = $c->components->{$class} || $class;
    $c->state(0);
    my $callsub = ( caller(1) )[3];

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
    $c->{depth}++;
    eval {
        if ( $c->debug )
        {
            my ( $elapsed, @state ) =
              $c->benchmark( $code, $class, $c, @{ $c->req->args } );
            push @{ $c->{stats} }, [ $action, sprintf( '%fs', $elapsed ) ];
            $c->state(@state);
        }
        else {
            $c->state( &$code( $class, $c, @{ $c->req->args } ) || 0 );
        }
    };
    $c->{depth}--;

    if ( my $error = $@ ) {

        if ( $error eq $DETACH ) { die $DETACH if $c->{depth} > 1 }
        else {
            unless ( ref $error ) {
                chomp $error;
                $error = qq/Caught exception "$error"/;
            }

            $c->log->error($error);
            $c->error($error);
            $c->state(0);
        }
    }
    return $c->state;
}

=item $c->finalize

Finalize request.

=cut

sub finalize {
    my $c = shift;

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

=item $c->finalize_body

Finalize body.

=cut

sub finalize_body { my $c = shift; $c->engine->finalize_body( $c, @_ ) }

=item $c->finalize_cookies

Finalize cookies.

=cut

sub finalize_cookies { my $c = shift; $c->engine->finalize_cookies( $c, @_ ) }

=item $c->finalize_error

Finalize error.

=cut

sub finalize_error { my $c = shift; $c->engine->finalize_error( $c, @_ ) }

=item $c->finalize_headers

Finalize headers.

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

=item $c->finalize_output

An alias for finalize_body.

=item $c->finalize_read

Finalize the input after reading is complete.

=cut

sub finalize_read { my $c = shift; $c->engine->finalize_read( $c, @_ ) }

=item $c->finalize_uploads

Finalize uploads.  Cleans up any temporary files.

=cut

sub finalize_uploads { my $c = shift; $c->engine->finalize_uploads( $c, @_ ) }

=item $c->get_action( $action, $namespace, $inherit )

Get an action in a given namespace.

=cut

sub get_action { my $c = shift; $c->dispatcher->get_action( $c, @_ ) }

=item handle_request( $class, @arguments )

Handles the request.

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
            my $elapsed;
            ( $elapsed, $status ) = $class->benchmark($handler);
            $elapsed = sprintf '%f', $elapsed;
            my $av = sprintf '%.3f',
              ( $elapsed == 0 ? '??' : ( 1 / $elapsed ) );
            my $t = Text::ASCIITable->new;
            $t->setCols( 'Action', 'Time' );
            $t->setColWidth( 'Action', 64, 1 );
            $t->setColWidth( 'Time',   9,  1 );

            for my $stat (@stats) { $t->addRow( $stat->[0], $stat->[1] ) }
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

=item $c->prepare(@arguments)

Turns the engine-specific request( Apache, CGI ... )
into a Catalyst context .

=cut

sub prepare {
    my ( $class, @arguments ) = @_;

    my $c = bless {
        counter => {},
        depth   => 0,
        request => Catalyst::Request->new(
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
        response => Catalyst::Response->new(
            {
                body    => '',
                cookies => {},
                headers => HTTP::Headers->new(),
                status  => 200
            }
        ),
        stash => {},
        state => 0
    }, $class;

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

    $c->prepare_action;
    my $method  = $c->req->method  || '';
    my $path    = $c->req->path    || '';
    my $address = $c->req->address || '';

    $c->log->debug(qq/"$method" request for "$path" from $address/)
      if $c->debug;

    return $c;
}

=item $c->prepare_action

Prepare action.

=cut

sub prepare_action { my $c = shift; $c->dispatcher->prepare_action( $c, @_ ) }

=item $c->prepare_body

Prepare message body.

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
        my $t = Text::ASCIITable->new;
        $t->setCols( 'Key', 'Value' );
        $t->setColWidth( 'Key',   37, 1 );
        $t->setColWidth( 'Value', 36, 1 );
        $t->alignCol( 'Value', 'right' );
        for my $key ( sort keys %{ $c->req->body_parameters } ) {
            my $param = $c->req->body_parameters->{$key};
            my $value = defined($param) ? $param : '';
            $t->addRow( $key,
                ref $value eq 'ARRAY' ? ( join ', ', @$value ) : $value );
        }
        $c->log->debug( "Body Parameters are:\n" . $t->draw );
    }
}

=item $c->prepare_body_chunk( $chunk )

Prepare a chunk of data before sending it to HTTP::Body.

=cut

sub prepare_body_chunk {
    my $c = shift;
    $c->engine->prepare_body_chunk( $c, @_ );
}

=item $c->prepare_body_parameters

Prepare body parameters.

=cut

sub prepare_body_parameters {
    my $c = shift;
    $c->engine->prepare_body_parameters( $c, @_ );
}

=item $c->prepare_connection

Prepare connection.

=cut

sub prepare_connection {
    my $c = shift;
    $c->engine->prepare_connection( $c, @_ );
}

=item $c->prepare_cookies

Prepare cookies.

=cut

sub prepare_cookies { my $c = shift; $c->engine->prepare_cookies( $c, @_ ) }

=item $c->prepare_headers

Prepare headers.

=cut

sub prepare_headers { my $c = shift; $c->engine->prepare_headers( $c, @_ ) }

=item $c->prepare_parameters

Prepare parameters.

=cut

sub prepare_parameters {
    my $c = shift;
    $c->prepare_body_parameters;
    $c->engine->prepare_parameters( $c, @_ );
}

=item $c->prepare_path

Prepare path and base.

=cut

sub prepare_path { my $c = shift; $c->engine->prepare_path( $c, @_ ) }

=item $c->prepare_query_parameters

Prepare query parameters.

=cut

sub prepare_query_parameters {
    my $c = shift;

    $c->engine->prepare_query_parameters( $c, @_ );

    if ( $c->debug && keys %{ $c->request->query_parameters } ) {
        my $t = Text::ASCIITable->new;
        $t->setCols( 'Key', 'Value' );
        $t->setColWidth( 'Key',   37, 1 );
        $t->setColWidth( 'Value', 36, 1 );
        $t->alignCol( 'Value', 'right' );
        for my $key ( sort keys %{ $c->req->query_parameters } ) {
            my $param = $c->req->query_parameters->{$key};
            my $value = defined($param) ? $param : '';
            $t->addRow( $key,
                ref $value eq 'ARRAY' ? ( join ', ', @$value ) : $value );
        }
        $c->log->debug( "Query Parameters are:\n" . $t->draw );
    }
}

=item $c->prepare_read

Prepare the input for reading.

=cut

sub prepare_read { my $c = shift; $c->engine->prepare_read( $c, @_ ) }

=item $c->prepare_request

Prepare the engine request.

=cut

sub prepare_request { my $c = shift; $c->engine->prepare_request( $c, @_ ) }

=item $c->prepare_uploads

Prepare uploads.

=cut

sub prepare_uploads {
    my $c = shift;

    $c->engine->prepare_uploads( $c, @_ );

    if ( $c->debug && keys %{ $c->request->uploads } ) {
        my $t = Text::ASCIITable->new;
        $t->setCols( 'Key', 'Filename', 'Type', 'Size' );
        $t->setColWidth( 'Key',      12, 1 );
        $t->setColWidth( 'Filename', 28, 1 );
        $t->setColWidth( 'Type',     18, 1 );
        $t->setColWidth( 'Size',     9,  1 );
        $t->alignCol( 'Size', 'left' );
        for my $key ( sort keys %{ $c->request->uploads } ) {
            my $upload = $c->request->uploads->{$key};
            for my $u ( ref $upload eq 'ARRAY' ? @{$upload} : ($upload) ) {
                $t->addRow( $key, $u->filename, $u->type, $u->size );
            }
        }
        $c->log->debug( "File Uploads are:\n" . $t->draw );
    }
}

=item $c->prepare_write

Prepare the output for writing.

=cut

sub prepare_write { my $c = shift; $c->engine->prepare_write( $c, @_ ) }

=item $c->read( [$maxlength] )

Read a chunk of data from the request body.  This method is designed to be
used in a while loop, reading $maxlength bytes on every call.  $maxlength
defaults to the size of the request if not specified.

You have to set MyApp->config->{parse_on_demand} to use this directly.

=cut

sub read { my $c = shift; return $c->engine->read( $c, @_ ) }

=item $c->run

Starts the engine.

=cut

sub run { my $c = shift; return $c->engine->run( $c, @_ ) }

=item $c->set_action( $action, $code, $namespace, $attrs )

Set an action in a given namespace.

=cut

sub set_action { my $c = shift; $c->dispatcher->set_action( $c, @_ ) }

=item $c->setup_actions($component)

Setup actions for a component.

=cut

sub setup_actions { my $c = shift; $c->dispatcher->setup_actions( $c, @_ ) }

=item $c->setup_components

Setup components.

=cut

sub setup_components {
    my $class = shift;

    my $callback = sub {
        my ( $component, $context ) = @_;

        unless ( $component->isa('Catalyst::Base') ) {
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

    eval {
        Module::Pluggable::Fast->import(
            name   => '_catalyst_components',
            search => [
                "$class\::Controller", "$class\::C",
                "$class\::Model",      "$class\::M",
                "$class\::View",       "$class\::V"
            ],
            callback => $callback
        );
    };

    if ( my $error = $@ ) {

        chomp $error;

        Catalyst::Exception->throw(
            message => qq/Couldn't load components "$error"/ );
    }

    for my $component ( $class->_catalyst_components($class) ) {
        $class->components->{ ref $component || $component } = $component;
    }
}

=item $c->setup_dispatcher

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
        $dispatcher = 'Catalyst::Dispatcher';
    }

    $dispatcher->require;

    if ($@) {
        Catalyst::Exception->throw(
            message => qq/Couldn't load dispatcher "$dispatcher", "$@"/ );
    }

    # dispatcher instance
    $class->dispatcher( $dispatcher->new );
}

=item $c->setup_engine

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
        $engine = 'Catalyst::Engine::CGI';
    }

    $engine->require;

    if ($@) {
        Catalyst::Exception->throw( message =>
qq/Couldn't load engine "$engine" (maybe you forgot to install it?), "$@"/
        );
    }

    # engine instance
    $class->engine( $engine->new );
}

=item $c->setup_home

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

=item $c->setup_log

=cut

sub setup_log {
    my ( $class, $debug ) = @_;

    unless ( $class->log ) {
        $class->log( Catalyst::Log->new );
    }

    if ( $ENV{CATALYST_DEBUG} || $ENV{ uc($class) . '_DEBUG' } || $debug ) {
        no strict 'refs';
        *{"$class\::debug"} = sub { 1 };
        $class->log->debug('Debug messages enabled');
    }
}

=item $c->setup_plugins

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

=item $c->write( $data )

Writes $data to the output stream.  When using this method directly, you will
need to manually set the Content-Length header to the length of your output
data, if known.

=cut

sub write {
    my $c = shift;

    # Finalize headers if someone manually writes output
    $c->finalize_headers;

    return $c->engine->write( $c, @_ );
}

=item version

Returns the Catalyst version number. mostly useful for powered by messages
in template systems.

=cut

sub version { return $Catalyst::VERSION }

=back

=head1 CASE SENSITIVITY

By default Catalyst is not case sensitive, so C<MyApp::C::FOO::Bar> becomes
C</foo/bar>.

But you can activate case sensitivity with a config parameter.

    MyApp->config->{case_sensitive} = 1;

So C<MyApp::C::Foo::Bar> becomes C</Foo/Bar>.

=head1 ON-DEMAND PARSER

The request body is usually parsed at the beginning of a request,
but if you want to handle input yourself or speed things up a bit
you can enable on-demand parsing with a config parameter.

    MyApp->config->{parse_on_demand} = 1;
    
=head1 PROXY SUPPORT

Many production servers operate using the common double-server approach, with
a lightweight frontend web server passing requests to a larger backend
server.  An application running on the backend server must deal with two
problems: the remote user always appears to be '127.0.0.1' and the server's
hostname will appear to be 'localhost' regardless of the virtual host the
user connected through.

Catalyst will automatically detect this situation when you are running both
the frontend and backend servers on the same machine.  The following changes
are made to the request.

    $c->req->address is set to the user's real IP address, as read from the
    HTTP_X_FORWARDED_FOR header.
    
    The host value for $c->req->base and $c->req->uri is set to the real host,
    as read from the HTTP_X_FORWARDED_HOST header.

Obviously, your web server must support these 2 headers for this to work.

In a more complex server farm environment where you may have your frontend
proxy server(s) on different machines, you will need to set a configuration
option to tell Catalyst to read the proxied data from the headers.

    MyApp->config->{using_frontend_proxy} = 1;
    
If you do not wish to use the proxy support at all, you may set:

    MyApp->config->{ignore_frontend_proxy} = 1;

=head1 THREAD SAFETY

Catalyst has been tested under Apache 2's threading mpm_worker, mpm_winnt,
and the standalone forking HTTP server on Windows.  We believe the Catalyst
core to be thread-safe.

If you plan to operate in a threaded environment, remember that all other
modules you are using must also be thread-safe.  Some modules, most notably
DBD::SQLite, are not thread-safe.

=head1 SUPPORT

IRC:

    Join #catalyst on irc.perl.org.

Mailing-Lists:

    http://lists.rawmode.org/mailman/listinfo/catalyst
    http://lists.rawmode.org/mailman/listinfo/catalyst-dev

Web:

    http://catalyst.perl.org

=head1 SEE ALSO

=over 4

=item L<Catalyst::Manual> - The Catalyst Manual

=item L<Catalyst::Engine> - Core Engine

=item L<Catalyst::Log> - The Log Class.

=item L<Catalyst::Request> - The Request Object

=item L<Catalyst::Response> - The Response Object

=item L<Catalyst::Test> - The test suite.

=back

=head1 CREDITS

Andy Grundman

Andy Wardley

Andreas Marienborg

Andrew Bramble

Andrew Ford

Andrew Ruthven

Arthur Bergman

Autrijus Tang

Christian Hansen

Christopher Hicks

Dan Sully

Danijel Milicevic

David Naughton

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
