package Catalyst::Context;

use Moose;
use bytes;
use B::Hooks::EndOfScope ();
use Catalyst::Exception;
use Catalyst::Exception::Detach;
use Catalyst::Exception::Go;
use Catalyst::Request;
use Catalyst::Request::Upload;
use Catalyst::Response;
use Catalyst::Utils;
use File::stat;
use Text::SimpleTable ();
use Path::Class::Dir ();
use Path::Class::File ();
use URI ();
use URI::http;
use URI::https;
use Tree::Simple::Visitor::FindByUID;
use utf8;
use Carp qw/croak carp shortmess/;


has action => (is => 'rw');
has counter => (is => 'rw', default => sub { {} });
has namespace => (is => 'rw');
has request_class => (is => 'ro', default => 'Catalyst::Request');
has request => (is => 'rw', default => sub { $_[0]->request_class->new({}) }, required => 1, lazy => 1);
has response_class => (is => 'ro', default => 'Catalyst::Response');
has response => (is => 'rw', default => sub { $_[0]->response_class->new({}) }, required => 1, lazy => 1);
has stack => (is => 'ro', default => sub { [] });
has stash => (is => 'rw', default => sub { {} });
has state => (is => 'rw', default => 0);
has stats => (is => 'rw');

has 'application' => (
    isa       => 'Catalyst',
    is        => 'ro',
    handles   => [
        qw/
        controllers 
        models 
        views 
        component 
        config
        log
        debug
        dispatcher
        engine
        path_to 
        plugin 
        setup_finalize 
        welcome_message 
        components
        context_class
        dispatcher_class
        prepare 
        engine_class
        setup_actions
        search_extra
        root
        parse_on_demand
        name
        ignore_frontend_proxy
        home
        default_model
        default_view
        version
        use_stats
        stats_class
        set_action

        ran_setup
        _comp_search_prefixes
        _filter_component
       /
   ],
);

sub depth { scalar @{ shift->stack || [] }; }

sub req {
    my $self = shift; return $self->request(@_);
}
sub res {
    my $self = shift; return $self->response(@_);
}

# For backwards compatibility
sub finalize_output { shift->finalize_body(@_) };

# For statistics
our $COUNT     = 1;
our $START     = time;
our $RECURSION = 1000;
our $DETACH    = Catalyst::Exception::Detach->new;
our $GO        = Catalyst::Exception::Go->new;



=head1 METHODS

=head2 INFORMATION ABOUT THE CURRENT REQUEST

=head2 $c->action

Returns a L<Catalyst::Action> object for the current action, which
stringifies to the action name. See L<Catalyst::Action>.

=head2 $c->namespace

Returns the namespace of the current action, i.e., the URI prefix
corresponding to the controller of the current action. For example:

    # in Controller::Foo::Bar
    $c->namespace; # returns 'foo/bar';

=head2 $c->request

=head2 $c->req

Returns the current L<Catalyst::Request> object, giving access to
information about the current client request (including parameters,
cookies, HTTP headers, etc.). See L<Catalyst::Request>.

=head2 REQUEST FLOW HANDLING

=head2 $c->forward( $action [, \@arguments ] )

=head2 $c->forward( $class, $method, [, \@arguments ] )

Forwards processing to another action, by its private name. If you give a
class name but no method, C<process()> is called. You may also optionally
pass arguments in an arrayref. The action will receive the arguments in
C<@_> and C<< $c->req->args >>. Upon returning from the function,
C<< $c->req->args >> will be restored to the previous values.

Any data C<return>ed from the action forwarded to, will be returned by the
call to forward.

    my $foodata = $c->forward('/foo');
    $c->forward('index');
    $c->forward(qw/MyApp::Model::DBIC::Foo do_stuff/);
    $c->forward('MyApp::View::TT');

Note that L<< forward|/"$c->forward( $action [, \@arguments ] )" >> implies
an C<< eval { } >> around the call (actually
L<< execute|/"$c->execute( $class, $coderef )" >> does), thus de-fatalizing
all 'dies' within the called action. If you want C<die> to propagate you
need to do something like:

    $c->forward('foo');
    die $c->error if $c->error;

Or make sure to always return true values from your actions and write
your code like this:

    $c->forward('foo') || return;
    
Another note is that C<< $c->forward >> always returns a scalar because it
actually returns $c->state which operates in a scalar context.
Thus, something like:

    return @array;
    
in an action that is forwarded to is going to return a scalar, 
i.e. how many items are in that array, which is probably not what you want.
If you need to return an array then return a reference to it, 
or stash it like so:

    $c->stash->{array} = \@array;

and access it from the stash.

=cut

sub forward { 
    my $c = shift; 
    no warnings 'recursion'; 
    my $dispatcher = $c->dispatcher;
    $dispatcher->forward( $c, @_ );
}

=head2 $c->detach( $action [, \@arguments ] )

=head2 $c->detach( $class, $method, [, \@arguments ] )

=head2 $c->detach()

The same as L<< forward|/"$c->forward( $action [, \@arguments ] )" >>, but
doesn't return to the previous action when processing is finished.

When called with no arguments it escapes the processing chain entirely.

=cut

sub detach { my $c = shift; $c->dispatcher->detach( $c, @_ ) }

=head2 $c->visit( $action [, \@captures, \@arguments ] )

=head2 $c->visit( $class, $method, [, \@captures, \@arguments ] )

Almost the same as L<< forward|/"$c->forward( $action [, \@arguments ] )" >>,
but does a full dispatch, instead of just calling the new C<$action> /
C<< $class->$method >>. This means that C<begin>, C<auto> and the method
you go to are called, just like a new request.

In addition both C<< $c->action >> and C<< $c->namespace >> are localized.
This means, for example, that C<< $c->action >> methods such as
L<name|Catalyst::Action/name>, L<class|Catalyst::Action/class> and
L<reverse|Catalyst::Action/reverse> return information for the visited action
when they are invoked within the visited action.  This is different from the
behavior of L<< forward|/"$c->forward( $action [, \@arguments ] )" >>, which
continues to use the $c->action object from the caller action even when
invoked from the callee.

C<< $c->stash >> is kept unchanged.

In effect, L<< visit|/"$c->visit( $action [, \@captures, \@arguments ] )" >>
allows you to "wrap" another action, just as it would have been called by
dispatching from a URL, while the analogous
L<< go|/"$c->go( $action [, \@captures, \@arguments ] )" >> allows you to
transfer control to another action as if it had been reached directly from a URL.

=cut

sub visit { my $c = shift; $c->dispatcher->visit( $c, @_ ) }

=head2 $c->go( $action [, \@captures, \@arguments ] )

=head2 $c->go( $class, $method, [, \@captures, \@arguments ] )

The relationship between C<go> and 
L<< visit|/"$c->visit( $action [, \@captures, \@arguments ] )" >> is the same as
the relationship between 
L<< forward|/"$c->forward( $class, $method, [, \@arguments ] )" >> and
L<< detach|/"$c->detach( $action [, \@arguments ] )" >>. Like C<< $c->visit >>,
C<< $c->go >> will perform a full dispatch on the specified action or method,
with localized C<< $c->action >> and C<< $c->namespace >>. Like C<detach>,
C<go> escapes the processing of the current request chain on completion, and
does not return to its caller.

=cut

sub go { my $c = shift; $c->dispatcher->go( $c, @_ ) }

=head2 $c->response

=head2 $c->res

Returns the current L<Catalyst::Response> object, see there for details.

=head2 $c->stash

Returns a hashref to the stash, which may be used to store data and pass
it between components during a request. You can also set hash keys by
passing arguments. The stash is automatically sent to the view. The
stash is cleared at the end of a request; it cannot be used for
persistent storage (for this you must use a session; see
L<Catalyst::Plugin::Session> for a complete system integrated with
Catalyst).

    $c->stash->{foo} = $bar;
    $c->stash( { moose => 'majestic', qux => 0 } );
    $c->stash( bar => 1, gorch => 2 ); # equivalent to passing a hashref

    # stash is automatically passed to the view for use in a template
    $c->forward( 'MyApp::View::TT' );

=cut

around stash => sub {
    my $orig = shift;
    my $c = shift;
    my $stash = $orig->($c);
    if (@_) {
        my $new_stash = @_ > 1 ? {@_} : $_[0];
        croak('stash takes a hash or hashref') unless ref $new_stash;
        foreach my $key ( keys %$new_stash ) {
          $stash->{$key} = $new_stash->{$key};
        }
    }

    return $stash;
};


=head2 $c->error

=head2 $c->error($error, ...)

=head2 $c->error($arrayref)

Returns an arrayref containing error messages.  If Catalyst encounters an
error while processing a request, it stores the error in $c->error.  This
method should only be used to store fatal error messages.

    my @error = @{ $c->error };

Add a new error.

    $c->error('Something bad happened');

=cut

sub error {
    my $c = shift;
    if ( $_[0] ) {
        my $error = ref $_[0] eq 'ARRAY' ? $_[0] : [@_];
        croak @$error unless ref $c;
        push @{ $c->{error} }, @$error;
    }
    elsif ( defined $_[0] ) { $c->{error} = undef }
    return $c->{error} || [];
}


=head2 $c->state

Contains the return value of the last executed action.   
Note that << $c->state >> operates in a scalar context which means that all
values it returns are scalar.

=head2 $c->clear_errors

Clear errors.  You probably don't want to clear the errors unless you are
implementing a custom error screen.

This is equivalent to running

    $c->error(0);

=cut

sub clear_errors {
    my $c = shift;
    $c->error(0);
}

=head2 COMPONENT ACCESSORS

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

=head2 $c->model($name)

Gets a L<Catalyst::Model> instance by name.

    $c->model('Foo')->do_stuff;

Any extra arguments are directly passed to ACCEPT_CONTEXT.

If the name is omitted, it will look for
 - a model object in $c->stash->{current_model_instance}, then
 - a model name in $c->stash->{current_model}, then
 - a config setting 'default_model', or
 - check if there is only one model, and return it if that's the case.

If you want to search for models, pass in a regexp as the argument.

    # find all models that start with Foo
    my @foo_models = $c->model(qr{^Foo});

=cut

sub model {
    my ( $c, $name, @args ) = @_;
    my $appclass = ref($c) || $c;
    if( $name ) {
        my @result = $c->_comp_search_prefixes( $name, qw/Model M/ );
        return map { $c->_filter_component( $_, @args ) } @result if ref $name;
        return $c->_filter_component( $result[ 0 ], @args );
    }

    if (ref $c) {
        return $c->stash->{current_model_instance}
          if $c->stash->{current_model_instance};
        return $c->model( $c->stash->{current_model} )
          if $c->stash->{current_model};
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


=head2 $c->view($name)

Gets a L<Catalyst::View> instance by name.

    $c->view('Foo')->do_stuff;

Any extra arguments are directly passed to ACCEPT_CONTEXT.

If the name is omitted, it will look for
 - a view object in $c->stash->{current_view_instance}, then
 - a view name in $c->stash->{current_view}, then
 - a config setting 'default_view', or
 - check if there is only one view, and return it if that's the case.

If you want to search for views, pass in a regexp as the argument.

    # find all views that start with Foo
    my @foo_views = $c->view(qr{^Foo});

=cut

sub view {
    my ( $c, $name, @args ) = @_;

    my $appclass = ref($c) || $c;
    if( $name ) {
        my @result = $c->_comp_search_prefixes( $name, qw/View V/ );
        return map { $c->_filter_component( $_, @args ) } @result if ref $name;
        return $c->_filter_component( $result[ 0 ], @args );
    }

    if (ref $c) {
        return $c->stash->{current_view_instance}
          if $c->stash->{current_view_instance};
        return $c->view( $c->stash->{current_view} )
          if $c->stash->{current_view};
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



=head2 $c->uri_for( $path, @args?, \%query_values? )

=head2 $c->uri_for( $action, \@captures?, @args?, \%query_values? )

Constructs an absolute L<URI> object based on the application root, the
provided path, and the additional arguments and query parameters provided.
When used as a string, provides a textual URI.

If the first argument is a string, it is taken as a public URI path relative
to C<< $c->namespace >> (if it doesn't begin with a forward slash) or
relative to the application root (if it does). It is then merged with
C<< $c->request->base >>; any C<@args> are appended as additional path
components; and any C<%query_values> are appended as C<?foo=bar> parameters.

If the first argument is a L<Catalyst::Action> it represents an action which
will have its path resolved using C<< $c->dispatcher->uri_for_action >>. The
optional C<\@captures> argument (an arrayref) allows passing the captured
variables that are needed to fill in the paths of Chained and Regex actions;
once the path is resolved, C<uri_for> continues as though a path was
provided, appending any arguments or parameters and creating an absolute
URI.

The captures for the current request can be found in
C<< $c->request->captures >>, and actions can be resolved using
C<< Catalyst::Controller->action_for($name) >>. If you have a private action
path, use C<< $c->uri_for_action >> instead.

  # Equivalent to $c->req->uri
  $c->uri_for($c->action, $c->req->captures,
      @{ $c->req->args }, $c->req->params);

  # For the Foo action in the Bar controller
  $c->uri_for($c->controller('Bar')->action_for('Foo'));

  # Path to a static resource
  $c->uri_for('/static/images/logo.png');

=cut

sub uri_for {
    my ( $c, $path, @args ) = @_;

    if (blessed($path) && $path->isa('Catalyst::Controller')) {
        $path = $path->path_prefix;
        $path =~ s{/+\z}{};
        $path .= '/';
    }

    if ( blessed($path) ) { # action object
        my $captures = ( scalar @args && ref $args[0] eq 'ARRAY'
                         ? shift(@args)
                         : [] );
        my $action = $path;
        $path = $c->dispatcher->uri_for_action($action, $captures);
        if (not defined $path) {
            $c->log->debug(qq/Can't find uri_for action '$action' @$captures/)
                if $c->debug;
            return undef;
        }
        $path = '/' if $path eq '';
    }

    undef($path) if (defined $path && $path eq '');

    my $params =
      ( scalar @args && ref $args[$#args] eq 'HASH' ? pop @args : {} );

    carp "uri_for called with undef argument" if grep { ! defined $_ } @args;
    s/([^$URI::uric])/$URI::Escape::escapes{$1}/go for @args;

    unshift(@args, $path);

    unless (defined $path && $path =~ s!^/!!) { # in-place strip
        my $namespace = $c->namespace;
        if (defined $path) { # cheesy hack to handle path '../foo'
           $namespace =~ s{(?:^|/)[^/]+$}{} while $args[0] =~ s{^\.\./}{};
        }
        unshift(@args, $namespace || '');
    }

    # join args with '/', or a blank string
    my $args = join('/', grep { defined($_) } @args);
    $args =~ s/\?/%3F/g; # STUPID STUPID SPECIAL CASE
    $args =~ s!^/+!!;
    my $base = $c->req->base;
    my $class = ref($base);
    $base =~ s{(?<!/)$}{/};

    my $query = '';

    if (my @keys = keys %$params) {
      # somewhat lifted from URI::_query's query_form
      $query = '?'.join('&', map {
          my $val = $params->{$_};
          s/([;\/?:@&=+,\$\[\]%])/$URI::Escape::escapes{$1}/go;
          s/ /+/g;
          my $key = $_;
          $val = '' unless defined $val;
          (map {
              my $param = "$_";
              utf8::encode( $param ) if utf8::is_utf8($param);
              # using the URI::Escape pattern here so utf8 chars survive
              $param =~ s/([^A-Za-z0-9\-_.!~*'() ])/$URI::Escape::escapes{$1}/go;
              $param =~ s/ /+/g;
              "${key}=$param"; } ( ref $val eq 'ARRAY' ? @$val : $val ));
      } @keys);
    }

    my $res = bless(\"${base}${args}${query}", $class);
    $res;
}

=head2 $c->uri_for_action( $path, \@captures?, @args?, \%query_values? )

=head2 $c->uri_for_action( $action, \@captures?, @args?, \%query_values? )

=over

=item $path

A private path to the Catalyst action you want to create a URI for.

This is a shortcut for calling C<< $c->dispatcher->get_action_by_path($path)
>> and passing the resulting C<$action> and the remaining arguments to C<<
$c->uri_for >>.

You can also pass in a Catalyst::Action object, in which case it is passed to
C<< $c->uri_for >>.

=back

=cut

sub uri_for_action {
    my ( $c, $path, @args ) = @_;
    my $action = blessed($path)
      ? $path
      : $c->dispatcher->get_action_by_path($path);
    unless (defined $action) {
      croak "Can't find action for path '$path'";
    }
    return $c->uri_for( $action, @args );
}



=head1 INTERNAL METHODS

=head2 $c->counter

Returns a hashref containing coderefs and execution counts (needed for
deep recursion detection).

=head2 $c->depth

Returns the number of actions on the current internal execution stack.

=head2 $c->dump_these

Returns a list of 2-element array references (name, structure) pairs
that will be dumped on the error page in debug mode.

=cut

sub dump_these {
    my $c = shift;
    [ Request => $c->req ],
    [ Response => $c->res ],
    [ Stash => $c->stash ],
    [ Config => $c->config ];
}


=head2 $c->execute( $class, $coderef )

Execute a coderef in given class and catch exceptions. Errors are available
via $c->error.

=cut

sub execute {
    my ( $c, $class, $code ) = @_;
    $class = $c->component($class) || $class;
    $c->state(0);

    if ( $c->depth >= $RECURSION ) {
        my $action = $code->reverse();
        $action = "/$action" unless $action =~ /->/;
        my $error = qq/Deep recursion detected calling "${action}"/;
        $c->log->error($error);
        $c->error($error);
        $c->state(0);
        return $c->state;
    }

    my $stats_info = $c->_stats_start_execute( $code ) if $c->use_stats;

    push( @{ $c->stack }, $code );

    no warnings 'recursion';
    eval { $c->state( $code->execute( $class, $c, @{ $c->req->args } ) || 0 ) };

    $c->_stats_finish_execute( $stats_info ) if $c->use_stats and $stats_info;

    my $last = pop( @{ $c->stack } );

    if ( my $error = $@ ) {
        if ( blessed($error) and $error->isa('Catalyst::Exception::Detach') ) {
            $error->rethrow if $c->depth > 1;
        }
        elsif ( blessed($error) and $error->isa('Catalyst::Exception::Go') ) {
            $error->rethrow if $c->depth > 0;
        }
        else {
            unless ( ref $error ) {
                no warnings 'uninitialized';
                chomp $error;
                my $class = $last->class;
                my $name  = $last->name;
                $error = qq/Caught exception in $class->$name "$error"/;
            }
            $c->error($error);
            $c->state(0);
        }
    }
    return $c->state;
}

sub _stats_start_execute {
    my ( $c, $code ) = @_;
    my $appclass = ref($c) || $c;
    return if ( ( $code->name =~ /^_.*/ )
        && ( !$c->config->{show_internal_actions} ) );

    my $action_name = $code->reverse();
    $c->counter->{$action_name}++;

    my $action = $action_name;
    $action = "/$action" unless $action =~ /->/;

    # determine if the call was the result of a forward
    # this is done by walking up the call stack and looking for a calling
    # sub of Catalyst::forward before the eval
    my $callsub = q{};
    for my $index ( 2 .. 11 ) {
        last
        if ( ( caller($index) )[0] eq 'Catalyst'
            && ( caller($index) )[3] eq '(eval)' );

        if ( ( caller($index) )[3] =~ /forward$/ ) {
            $callsub = ( caller($index) )[3];
            $action  = "-> $action";
            last;
        }
    }

    my $uid = $action_name . $c->counter->{$action_name};

    # is this a root-level call or a forwarded call?
    if ( $callsub =~ /forward$/ ) {
        my $parent = $c->stack->[-1];

        # forward, locate the caller
        if ( exists $c->counter->{"$parent"} ) {
            $c->stats->profile(
                begin  => $action,
                parent => "$parent" . $c->counter->{"$parent"},
                uid    => $uid,
            );
        }
        else {

            # forward with no caller may come from a plugin
            $c->stats->profile(
                begin => $action,
                uid   => $uid,
            );
        }
    }
    else {

        # root-level call
        $c->stats->profile(
            begin => $action,
            uid   => $uid,
        );
    }
    return $action;

}

sub _stats_finish_execute {
    my ( $c, $info ) = @_;
    $c->stats->profile( end => $info );
}

=head2 $c->finalize

Finalizes the request.

=cut

sub finalize {
    my $c = shift;

    for my $error ( @{ $c->error } ) {
        $c->log->error($error);
    }

    # Allow engine to handle finalize flow (for POE)
    my $engine = $c->engine;
    if ( my $code = $engine->can('finalize') ) {
        $engine->$code($c);
    }
    else {

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
    }

    if ($c->use_stats) {
        my $elapsed = sprintf '%f', $c->stats->elapsed;
        my $av = $elapsed == 0 ? '??' : sprintf '%.3f', 1 / $elapsed;
        $c->log->info(
            "Request took ${elapsed}s ($av/s)\n" . $c->stats->report . "\n" );
    }

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

    my $response = $c->response; #accessor calls can add up?

    # Check if we already finalized headers
    return if $response->finalized_headers;

    # Handle redirects
    if ( my $location = $response->redirect ) {
        $c->log->debug(qq/Redirecting to "$location"/) if $c->debug;
        $response->header( Location => $location );

        if ( !$response->has_body ) {
            # Add a default body if none is already present
            $response->body(
                qq{<html><body><p>This item has moved <a href="$location">here</a>.</p></body></html>}
            );
        }
    }

    # Content-Length
    if ( $response->body && !$response->content_length ) {

        # get the length from a filehandle
        if ( blessed( $response->body ) && $response->body->can('read') )
        {
            my $stat = stat $response->body;
            if ( $stat && $stat->size > 0 ) {
                $response->content_length( $stat->size );
            }
            else {
                $c->log->warn('Serving filehandle without a content-length');
            }
        }
        else {
            # everything should be bytes at this point, but just in case
            $response->content_length( bytes::length( $response->body ) );
        }
    }

    # Errors
    if ( $response->status =~ /^(1\d\d|[23]04)$/ ) {
        $response->headers->remove_header("Content-Length");
        $response->body('');
    }

    $c->finalize_cookies;

    $c->engine->finalize_headers( $c, @_ );

    # Done
    $response->finalized_headers(1);
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

=head2 $c->dispatch

Dispatches a request to actions.

=cut

sub dispatch { 
    my $c = shift; 
    my $dispatcher = $c->dispatcher;
    $dispatcher->dispatch( $c, @_ ) 
}

=head2 $c->prepare_action

Prepares action. See L<Catalyst::Dispatcher>.

=cut

sub prepare_action { my $c = shift; $c->dispatcher->prepare_action( $c, @_ ) }

=head2 $c->prepare_body

Prepares message body.

=cut

sub prepare_body {
    my $c = shift;

    return if $c->request->_has_body;

    # Initialize on-demand data
    $c->engine->prepare_body( $c, @_ );
    $c->prepare_parameters;
    $c->prepare_uploads;

    if ( $c->debug && keys %{ $c->req->body_parameters } ) {
        my $t = Text::SimpleTable->new( [ 35, 'Parameter' ], [ 36, 'Value' ] );
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

See L<Catalyst::Engine>.

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
        my $t = Text::SimpleTable->new( [ 35, 'Parameter' ], [ 36, 'Value' ] );
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
            [ 12, 'Parameter' ],
            [ 26, 'Filename' ],
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

You have to set C<< MyApp->config(parse_on_demand => 1) >> to use this
directly.

Warning: If you use read(), Catalyst will not process the body,
so you will not be able to access POST parameters or file uploads via
$c->request.  You must handle all body parsing yourself.

=cut

sub read { my $c = shift; return $c->engine->read( $c, @_ ) }

=head2 $c->run

Starts the engine.

=cut

sub run { my $c = shift; return $c->engine->run( $c, @_ ) }

=head2 $c->stack

Returns an arrayref of the internal execution stack (actions that are
currently executing).


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


no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Catalyst::Context - object for keeping request related state

=head1 ATTRIBUTES 

=head3 action

=head3 counter

=head3 namespace

=head3 request_class

=head3 request

=head3 response_class

=head3 response

=head3 stack

=head3 stash

=head3 state

=head3 stats

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Model>, L<Catalyst::View>, L<Catalyst::Controller>.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

