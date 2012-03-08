package Catalyst;

use Moose;
use Moose::Meta::Class ();
extends 'Catalyst::Component';
use Moose::Util qw/find_meta/;
use B::Hooks::EndOfScope ();
use Catalyst::Exception;
use Catalyst::Exception::Detach;
use Catalyst::Exception::Go;
use Catalyst::Log;
use Catalyst::Request;
use Catalyst::Request::Upload;
use Catalyst::Response;
use Catalyst::Utils;
use Catalyst::Controller;
use Data::OptList;
use Devel::InnerPackage ();
use Module::Pluggable::Object ();
use Text::SimpleTable ();
use Path::Class::Dir ();
use Path::Class::File ();
use URI ();
use URI::http;
use URI::https;
use Tree::Simple qw/use_weak_refs/;
use Tree::Simple::Visitor::FindByUID;
use Class::C3::Adopt::NEXT;
use List::MoreUtils qw/uniq/;
use attributes;
use String::RewritePrefix;
use Catalyst::EngineLoader;
use utf8;
use Carp qw/croak carp shortmess/;
use Try::Tiny;
use Plack::Middleware::Conditional;
use Plack::Middleware::ReverseProxy;
use Plack::Middleware::IIS6ScriptNameFix;
use Plack::Middleware::LighttpdScriptNameFix;

BEGIN { require 5.008003; }

has stack => (is => 'ro', default => sub { [] });
has stash => (is => 'rw', default => sub { {} });
has state => (is => 'rw', default => 0);
has stats => (is => 'rw');
has action => (is => 'rw');
has counter => (is => 'rw', default => sub { {} });
has request => (
    is => 'rw',
    default => sub {
        my $self = shift;
        my %p = ( _log => $self->log );
        $p{_uploadtmp} = $self->_uploadtmp if $self->_has_uploadtmp;
        $self->request_class->new(\%p);
    },
    lazy => 1,
);
has response => (
    is => 'rw',
    default => sub {
        my $self = shift;
        $self->response_class->new({ _log => $self->log });
    },
    lazy => 1,
);
has namespace => (is => 'rw');

sub depth { scalar @{ shift->stack || [] }; }
sub comp { shift->component(@_) }

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

#I imagine that very few of these really need to be class variables. if any.
#maybe we should just make them attributes with a default?
__PACKAGE__->mk_classdata($_)
  for qw/components arguments dispatcher engine log dispatcher_class
  engine_loader context_class request_class response_class stats_class
  setup_finished _psgi_app loading_psgi_file run_options/;

__PACKAGE__->dispatcher_class('Catalyst::Dispatcher');
__PACKAGE__->request_class('Catalyst::Request');
__PACKAGE__->response_class('Catalyst::Response');
__PACKAGE__->stats_class('Catalyst::Stats');

# Remember to update this in Catalyst::Runtime as well!

our $VERSION = '5.90011';

sub import {
    my ( $class, @arguments ) = @_;

    # We have to limit $class to Catalyst to avoid pushing Catalyst upon every
    # callers @ISA.
    return unless $class eq 'Catalyst';

    my $caller = caller();
    return if $caller eq 'main';

    my $meta = Moose::Meta::Class->initialize($caller);
    unless ( $caller->isa('Catalyst') ) {
        my @superclasses = ($meta->superclasses, $class, 'Catalyst::Controller');
        $meta->superclasses(@superclasses);
    }
    # Avoid possible C3 issues if 'Moose::Object' is already on RHS of MyApp
    $meta->superclasses(grep { $_ ne 'Moose::Object' } $meta->superclasses);

    unless( $meta->has_method('meta') ){
        if ($Moose::VERSION >= 1.15) {
            $meta->_add_meta_method('meta');
        }
        else {
            $meta->add_method(meta => sub { Moose::Meta::Class->initialize("${caller}") } );
        }
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
    sub foo : Chained('/') Args() { # called for /foo, /foo/1, /foo/1/2, etc.
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
    sub bar : Chained('/') PathPart('/bar/of/soap') Args() { ... }

    # called after all actions are finished
    sub end : Action {
        my ( $self, $c ) = @_;
        if ( scalar @{ $c->error } ) { ... } # handle errors
        return if $c->res->body; # already have a response
        $c->forward( 'MyApp::View::TT' ); # render template
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

Special flags like C<-Debug> can also be specified as
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

This sets the log level to 'debug' and enables full debug output on the
error screen. If you only want the latter, see L<< $c->debug >>.

=head2 -Home

Forces Catalyst to use a specific home directory, e.g.:

    use Catalyst qw[-Home=/usr/mst];

This can also be done in the shell environment by setting either the
C<CATALYST_HOME> environment variable or C<MYAPP_HOME>; where C<MYAPP>
is replaced with the uppercased name of your application, any "::" in
the name will be replaced with underscores, e.g. MyApp::Web should use
MYAPP_WEB_HOME. If both variables are set, the MYAPP_HOME one will be used.

If none of these are set, Catalyst will attempt to automatically detect the
home directory. If you are working in a development environment, Catalyst
will try and find the directory containing either Makefile.PL, Build.PL or
dist.ini. If the application has been installed into the system (i.e.
you have done C<make install>), then Catalyst will use the path to your
application module, without the .pm extension (e.g., /foo/MyApp if your
application was installed at /foo/MyApp.pm)

=head2 -Log

    use Catalyst '-Log=warn,fatal,error';

Specifies a comma-delimited list of log levels.

=head2 -Stats

Enables statistics collection and reporting.

   use Catalyst qw/-Stats=1/;

You can also force this setting from the system environment with CATALYST_STATS
or <MYAPP>_STATS. The environment settings override the application, with
<MYAPP>_STATS having the highest priority.

Stats are also enabled if L<< debugging |/"-Debug" >> is enabled.

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
    $c->forward(qw/Model::DBIC::Foo do_stuff/);
    $c->forward('View::TT');

Note that L<< forward|/"$c->forward( $action [, \@arguments ] )" >> implies
an C<< eval { } >> around the call (actually
L<< execute|/"$c->execute( $class, $coderef )" >> does), thus rendering all
exceptions thrown by the called action non-fatal and pushing them onto
$c->error instead. If you want C<die> to propagate you need to do something
like:

    $c->forward('foo');
    die join "\n", @{ $c->error } if @{ $c->error };

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

Keep in mind that the C<end> method used is that of the caller action. So a C<$c-E<gt>detach> inside a forwarded action would run the C<end> method from the original action requested.

=cut

sub forward { my $c = shift; no warnings 'recursion'; $c->dispatcher->forward( $c, @_ ) }

=head2 $c->detach( $action [, \@arguments ] )

=head2 $c->detach( $class, $method, [, \@arguments ] )

=head2 $c->detach()

The same as L<< forward|/"$c->forward( $action [, \@arguments ] )" >>, but
doesn't return to the previous action when processing is finished.

When called with no arguments it escapes the processing chain entirely.

=cut

sub detach { my $c = shift; $c->dispatcher->detach( $c, @_ ) }

=head2 $c->visit( $action [, \@arguments ] )

=head2 $c->visit( $action [, \@captures, \@arguments ] )

=head2 $c->visit( $class, $method, [, \@arguments ] )

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
invoked from the called action.

C<< $c->stash >> is kept unchanged.

In effect, L<< visit|/"$c->visit( $action [, \@captures, \@arguments ] )" >>
allows you to "wrap" another action, just as it would have been called by
dispatching from a URL, while the analogous
L<< go|/"$c->go( $action [, \@captures, \@arguments ] )" >> allows you to
transfer control to another action as if it had been reached directly from a URL.

=cut

sub visit { my $c = shift; $c->dispatcher->visit( $c, @_ ) }

=head2 $c->go( $action [, \@arguments ] )

=head2 $c->go( $action [, \@captures, \@arguments ] )

=head2 $c->go( $class, $method, [, \@arguments ] )

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

@arguments are arguments to the final destination of $action. @captures are
arguments to the intermediate steps, if any, on the way to the final sub of
$action.

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

    my $appclass = ref($c) || $c;
    if( $name ) {
        unless ( ref($name) ) { # Direct component hash lookup to avoid costly regexps
            my $comps = $c->components;
            my $check = $appclass."::Controller::".$name;
            return $c->_filter_component( $comps->{$check}, @args ) if exists $comps->{$check};
        }
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
        unless ( ref($name) ) { # Direct component hash lookup to avoid costly regexps
            my $comps = $c->components;
            my $check = $appclass."::Model::".$name;
            return $c->_filter_component( $comps->{$check}, @args ) if exists $comps->{$check};
        }
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
    return $c->model( $appclass->config->{default_model} )
      if $appclass->config->{default_model};

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
        unless ( ref($name) ) { # Direct component hash lookup to avoid costly regexps
            my $comps = $c->components;
            my $check = $appclass."::View::".$name;
            if( exists $comps->{$check} ) {
                return $c->_filter_component( $comps->{$check}, @args );
            }
            else {
                $c->log->warn( "Attempted to use view '$check', but does not exist" );
            }
        }
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
    return $c->view( $appclass->config->{default_view} )
      if $appclass->config->{default_view};

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

        return
            if $c->config->{disable_component_resolution_regex_fallback};

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
    MyApp::Model::Foo->config({ quux => 'frob', overrides => 'this' });

will mean that C<MyApp::Model::Foo> receives the following data when
constructed:

    MyApp::Model::Foo->new({
        bar => 'baz',
        quux => 'frob',
        overrides => 'me',
    });

It's common practice to use a Moose attribute
on the receiving component to access the config value.

    package MyApp::Model::Foo;

    use Moose;

    # this attr will receive 'baz' at construction time
    has 'bar' => (
        is  => 'rw',
        isa => 'Str',
    );

You can then get the value 'baz' by calling $c->model('Foo')->bar
(or $self->bar inside code in the model).

B<NOTE:> you MUST NOT call C<< $self->config >> or C<< __PACKAGE__->config >>
as a way of reading config within your code, as this B<will not> give you the
correctly merged config back. You B<MUST> take the config values supplied to
the constructor and use those instead.

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

The first three also set the log level to 'debug'.

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

sub plugin {
    my ( $class, $name, $plugin, @args ) = @_;

    # See block comment in t/unit_core_plugin.t
    $class->log->warn(qq/Adding plugin using the ->plugin method is deprecated, and will be removed in a future release/);

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

B<Note:> You B<should not> wrap this method with method modifiers
or bad things will happen - wrap the C<setup_finalize> method instead.

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
    if (my $engine = delete $flags->{engine}) {
        $class->log->warn("Specifying the engine in ->setup is no longer supported, see Catalyst::Upgrading");
    }
    $class->setup_engine();
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

    # Add our self to components, since we are also a component
    if( $class->isa('Catalyst::Controller') ){
      $class->components->{$class} = $class;
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

    if ($class->config->{case_sensitive}) {
        $class->log->warn($class . "->config->{case_sensitive} is set.");
        $class->log->warn("This setting is deprecated and planned to be removed in Catalyst 5.81.");
    }

    $class->setup_finalize;
    # Should be the last thing we do so that user things hooking
    # setup_finalize can log..
    $class->log->_flush() if $class->log->can('_flush');
    return 1; # Explicit return true as people have __PACKAGE__->setup as the last thing in their class. HATE.
}

=head2 $app->setup_finalize

A hook to attach modifiers to. This method does not do anything except set the
C<setup_finished> accessor.

Applying method modifiers to the C<setup> method doesn't work, because of quirky things done for plugin setup.

Example:

    after setup_finalize => sub {
        my $app = shift;

        ## do stuff here..
    };

=cut

sub setup_finalize {
    my ($class) = @_;
    $class->setup_finished(1);
}

=head2 $c->uri_for( $path?, @args?, \%query_values? )

=head2 $c->uri_for( $action, \@captures?, @args?, \%query_values? )

Constructs an absolute L<URI> object based on the application root, the
provided path, and the additional arguments and query parameters provided.
When used as a string, provides a textual URI.  If you need more flexibility
than this (i.e. the option to provide relative URIs etc.) see
L<Catalyst::Plugin::SmartURI>.

If no arguments are provided, the URI for the current action is returned.
To return the current action and also provide @args, use
C<< $c->uri_for( $c->action, @args ) >>.

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

    undef($path) if (defined $path && $path eq '');

    my $params =
      ( scalar @args && ref $args[$#args] eq 'HASH' ? pop @args : {} );

    carp "uri_for called with undef argument" if grep { ! defined $_ } @args;
    foreach my $arg (@args) {
        utf8::encode($arg) if utf8::is_utf8($arg);
        $arg =~ s/([^$URI::uric])/$URI::Escape::escapes{$1}/go;
    }

    if ( blessed($path) ) { # action object
        s|/|%2F|g for @args;
        my $captures = [ map { s|/|%2F|g; $_; }
                        ( scalar @args && ref $args[0] eq 'ARRAY'
                         ? @{ shift(@args) }
                         : ()) ];

        foreach my $capture (@$captures) {
            utf8::encode($capture) if utf8::is_utf8($capture);
            $capture =~ s/([^$URI::uric])/$URI::Escape::escapes{$1}/go;
        }

        my $action = $path;
        # ->uri_for( $action, \@captures_and_args, \%query_values? )
        if( !@args && $action->number_of_args ) {
            my $expanded_action = $c->dispatcher->expand_action( $action );

            my $num_captures = $expanded_action->number_of_captures;
            unshift @args, splice @$captures, $num_captures;
        }

       $path = $c->dispatcher->uri_for_action($action, $captures);
        if (not defined $path) {
            $c->log->debug(qq/Can't find uri_for action '$action' @$captures/)
                if $c->debug;
            return undef;
        }
        $path = '/' if $path eq '';
    }

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

=head2 $c->uri_for_action( $path, \@captures_and_args?, @args?, \%query_values? )

=head2 $c->uri_for_action( $action, \@captures_and_args?, @args?, \%query_values? )

=over

=item $path

A private path to the Catalyst action you want to create a URI for.

This is a shortcut for calling C<< $c->dispatcher->get_action_by_path($path)
>> and passing the resulting C<$action> and the remaining arguments to C<<
$c->uri_for >>.

You can also pass in a Catalyst::Action object, in which case it is passed to
C<< $c->uri_for >>.

Note that although the path looks like a URI that dispatches to the wanted action, it is not a URI, but an internal path to that action.

For example, if the action looks like:

 package MyApp::Controller::Users;

 sub lst : Path('the-list') {}

You can use:

 $c->uri_for_action('/users/lst')

and it will create the URI /users/the-list.

=item \@captures_and_args?

Optional array reference of Captures (i.e. C<<CaptureArgs or $c->req->captures>)
and arguments to the request. Usually used with L<Catalyst::DispatchType::Chained>
to interpolate all the parameters in the URI.

=item @args?

Optional list of extra arguments - can be supplied in the
C<< \@captures_and_args? >> array ref, or here - whichever is easier for your
code.

Your action can have zero, a fixed or a variable number of args (e.g.
C<< Args(1) >> for a fixed number or C<< Args() >> for a variable number)..

=item \%query_values?

Optional array reference of query parameters to append. E.g.

  { foo => 'bar' }

will generate

  /rest/of/your/uri?foo=bar

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
<pre>perldoc <a href="https://metacpan.org/module/Catalyst::Manual::Tutorial">Catalyst::Manual::Tutorial</a></code>
</pre>
<p>Afterwards you can go on to check out a more complete look at our features.</p>
<pre>
<code>perldoc <a href="https://metacpan.org/module/Catalyst::Manual::Intro">Catalyst::Manual::Intro</a>
<!-- Something else should go here, but the Catalyst::Manual link seems unhelpful -->
</code></pre>
                 <h2>What to do next?</h2>
                 <p>Next it's time to write an actual application. Use the
                    helper scripts to generate <a href="https://metacpan.org/search?q=Catalyst%3A%3AController">controllers</a>,
                    <a href="https://metacpan.org/search?q=Catalyst%3A%3AModel">models</a>, and
                    <a href="https://metacpan.org/search?q=Catalyst%3A%3AView">views</a>;
                    they can save you a lot of work.</p>
                    <pre><code>script/${prefix}_create.pl --help</code></pre>
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

=head2 run_options

Contains a hash of options passed from the application script, including
the original ARGV the script received, the processed values from that
ARGV and any extra arguments to the script which were not processed.

This can be used to add custom options to your application's scripts
and setup your application differently depending on the values of these
options.

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
    [ Request => $c->req ],
    [ Response => $c->res ],
    [ Stash => $c->stash ],
    [ Config => $c->config ];
}

=head2 $c->engine_class

Returns or sets the engine class.

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
    # N.B. This used to be combined, but I have seen $c get clobbered if so, and
    #      I have no idea how, ergo $ret (which appears to fix the issue)
    eval { my $ret = $code->execute( $class, $c, @{ $c->req->args } ) || 0; $c->state( $ret ) };

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
        }
        $c->state(0);
    }
    return $c->state;
}

sub _stats_start_execute {
    my ( $c, $code ) = @_;
    my $appclass = ref($c) || $c;
    return if ( ( $code->name =~ /^_.*/ )
        && ( !$appclass->config->{show_internal_actions} ) );

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
        if ( defined $parent && exists $c->counter->{"$parent"} ) {
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

    $c->log_response;

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
            $response->body(<<"EOF");
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"> 
  <head>
    <title>Moved</title>
  </head>
  <body>
     <p>This item has moved <a href="$location">here</a>.</p>
  </body>
</html>
EOF
            $response->content_type('text/html; charset=utf-8');
        }
    }

    # Content-Length
    if ( defined $response->body && length $response->body && !$response->content_length ) {

        # get the length from a filehandle
        if ( blessed( $response->body ) && $response->body->can('read') || ref( $response->body ) eq 'GLOB' )
        {
            my $size = -s $response->body;
            if ( $size ) {
                $response->content_length( $size );
            }
            else {
                $c->log->warn('Serving filehandle without a content-length');
            }
        }
        else {
            # everything should be bytes at this point, but just in case
            $response->content_length( length( $response->body ) );
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

=head2 $app->handle_request( @arguments )

Called to handle each HTTP request.

=cut

sub handle_request {
    my ( $class, @arguments ) = @_;

    # Always expect worst case!
    my $status = -1;
    try {
        if ($class->debug) {
            my $secs = time - $START || 1;
            my $av = sprintf '%.3f', $COUNT / $secs;
            my $time = localtime time;
            $class->log->info("*** Request $COUNT ($av/s) [$$] [$time] ***");
        }

        my $c = $class->prepare(@arguments);
        $c->dispatch;
        $status = $c->finalize;
    }
    catch {
        chomp(my $error = $_);
        $class->log->error(qq/Caught exception in engine "$error"/);
    };

    $COUNT++;

    if(my $coderef = $class->log->can('_flush')){
        $class->log->$coderef();
    }
    return $status;
}

=head2 $class->prepare( @arguments )

Creates a Catalyst context from an engine-specific request (Apache, CGI,
etc.).

=cut

has _uploadtmp => (
    is => 'ro',
    predicate => '_has_uploadtmp',
);

sub prepare {
    my ( $class, @arguments ) = @_;

    # XXX
    # After the app/ctxt split, this should become an attribute based on something passed
    # into the application.
    $class->context_class( ref $class || $class ) unless $class->context_class;

    my $uploadtmp = $class->config->{uploadtmp};
    my $c = $class->context_class->new({ $uploadtmp ? (_uploadtmp => $uploadtmp) : ()});

    #surely this is not the most efficient way to do things...
    $c->stats($class->stats_class->new)->enable($c->use_stats);
    if ( $c->debug || $c->config->{enable_catalyst_header} ) {
        $c->res->headers->header( 'X-Catalyst' => $Catalyst::VERSION );
    }

    try {
        # Allow engine to direct the prepare flow (for POE)
        if ( my $prepare = $c->engine->can('prepare') ) {
            $c->engine->$prepare( $c, @arguments );
        }
        else {
            $c->prepare_request(@arguments);
            $c->prepare_connection;
            $c->prepare_query_parameters;
            $c->prepare_headers; # Just hooks, no longer needed - they just
            $c->prepare_cookies; # cause the lazy attribute on req to build
            $c->prepare_path;

            # Prepare the body for reading, either by prepare_body
            # or the user, if they are using $c->read
            $c->prepare_read;

            # Parse the body unless the user wants it on-demand
            unless ( ref($c)->config->{parse_on_demand} ) {
                $c->prepare_body;
            }
        }
        $c->prepare_action;
    }
    # VERY ugly and probably shouldn't rely on ->finalize actually working
    catch {
        # failed prepare is always due to an invalid request, right?
        $c->response->status(400);
        $c->response->content_type('text/plain');
        $c->response->body('Bad Request');
        # Note we call finalize and then die here, which escapes
        # finalize being called in the enclosing block..
        # It in fact couldn't be called, as we don't return $c..
        # This is a mess - but I'm unsure you can fix this without
        # breaking compat for people doing crazy things (we should set
        # the 400 and just return the ctx here IMO, letting finalize get called
        # above...
        $c->finalize;
        die $_;
    };

    $c->log_request;

    return $c;
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
    # XXX - This is called on the engine (not the request) to maintain
    #       Engine::PSGI back compat.
    $c->engine->prepare_connection($c);
}

=head2 $c->prepare_cookies

Prepares cookies by ensuring that the attribute on the request
object has been built.

=cut

sub prepare_cookies { my $c = shift; $c->request->cookies }

=head2 $c->prepare_headers

Prepares request headers by ensuring that the attribute on the request
object has been built.

=cut

sub prepare_headers { my $c = shift; $c->request->headers }

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
}

=head2 $c->log_request

Writes information about the request to the debug logs.  This includes:

=over 4

=item * Request method, path, and remote IP address

=item * Query keywords (see L<Catalyst::Request/query_keywords>)

=item * Request parameters

=item * File uploads

=back

=cut

sub log_request {
    my $c = shift;

    return unless $c->debug;

    my($dump) = grep {$_->[0] eq 'Request' } $c->dump_these;
    my $request = $dump->[1];

    my ( $method, $path, $address ) = ( $request->method, $request->path, $request->address );
    $method ||= '';
    $path = '/' unless length $path;
    $address ||= '';
    $c->log->debug(qq/"$method" request for "$path" from "$address"/);

    $c->log_request_headers($request->headers);

    if ( my $keywords = $request->query_keywords ) {
        $c->log->debug("Query keywords are: $keywords");
    }

    $c->log_request_parameters( query => $request->query_parameters, $request->_has_body ? (body => $request->body_parameters) : () );

    $c->log_request_uploads($request);
}

=head2 $c->log_response

Writes information about the response to the debug logs by calling
C<< $c->log_response_status_line >> and C<< $c->log_response_headers >>.

=cut

sub log_response {
    my $c = shift;

    return unless $c->debug;

    my($dump) = grep {$_->[0] eq 'Response' } $c->dump_these;
    my $response = $dump->[1];

    $c->log_response_status_line($response);
    $c->log_response_headers($response->headers);
}

=head2 $c->log_response_status_line($response)

Writes one line of information about the response to the debug logs.  This includes:

=over 4

=item * Response status code

=item * Content-Type header (if present)

=item * Content-Length header (if present)

=back

=cut

sub log_response_status_line {
    my ($c, $response) = @_;

    $c->log->debug(
        sprintf(
            'Response Code: %s; Content-Type: %s; Content-Length: %s',
            $response->status                            || 'unknown',
            $response->headers->header('Content-Type')   || 'unknown',
            $response->headers->header('Content-Length') || 'unknown'
        )
    );
}

=head2 $c->log_response_headers($headers);

Hook method which can be wrapped by plugins to log the response headers.
No-op in the default implementation.

=cut

sub log_response_headers {}

=head2 $c->log_request_parameters( query => {}, body => {} )

Logs request parameters to debug logs

=cut

sub log_request_parameters {
    my $c          = shift;
    my %all_params = @_;

    return unless $c->debug;

    my $column_width = Catalyst::Utils::term_width() - 44;
    foreach my $type (qw(query body)) {
        my $params = $all_params{$type};
        next if ! keys %$params;
        my $t = Text::SimpleTable->new( [ 35, 'Parameter' ], [ $column_width, 'Value' ] );
        for my $key ( sort keys %$params ) {
            my $param = $params->{$key};
            my $value = defined($param) ? $param : '';
            $t->row( $key, ref $value eq 'ARRAY' ? ( join ', ', @$value ) : $value );
        }
        $c->log->debug( ucfirst($type) . " Parameters are:\n" . $t->draw );
    }
}

=head2 $c->log_request_uploads

Logs file uploads included in the request to the debug logs.
The parameter name, filename, file type, and file size are all included in
the debug logs.

=cut

sub log_request_uploads {
    my $c = shift;
    my $request = shift;
    return unless $c->debug;
    my $uploads = $request->uploads;
    if ( keys %$uploads ) {
        my $t = Text::SimpleTable->new(
            [ 12, 'Parameter' ],
            [ 26, 'Filename' ],
            [ 18, 'Type' ],
            [ 9,  'Size' ]
        );
        for my $key ( sort keys %$uploads ) {
            my $upload = $uploads->{$key};
            for my $u ( ref $upload eq 'ARRAY' ? @{$upload} : ($upload) ) {
                $t->row( $key, $u->filename, $u->type, $u->size );
            }
        }
        $c->log->debug( "File Uploads are:\n" . $t->draw );
    }
}

=head2 $c->log_request_headers($headers);

Hook method which can be wrapped by plugins to log the request headers.
No-op in the default implementation.

=cut

sub log_request_headers {}

=head2 $c->log_headers($type => $headers)

Logs L<HTTP::Headers> (either request or response) to the debug logs.

=cut

sub log_headers {
    my $c       = shift;
    my $type    = shift;
    my $headers = shift;    # an HTTP::Headers instance

    return unless $c->debug;

    my $column_width = Catalyst::Utils::term_width() - 28;
    my $t = Text::SimpleTable->new( [ 15, 'Header Name' ], [ $column_width, 'Value' ] );
    $headers->scan(
        sub {
            my ( $name, $value ) = @_;
            $t->row( $name, $value );
        }
    );
    $c->log->debug( ucfirst($type) . " Headers:\n" . $t->draw );
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
}

=head2 $c->prepare_write

Prepares the output for writing.

=cut

sub prepare_write { my $c = shift; $c->engine->prepare_write( $c, @_ ) }

=head2 $c->request_class

Returns or sets the request class. Defaults to L<Catalyst::Request>.

=head2 $c->response_class

Returns or sets the response class. Defaults to L<Catalyst::Response>.

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

sub read { my $c = shift; return $c->request->read( @_ ) }

=head2 $c->run

Starts the engine.

=cut

sub run {
  my $app = shift;
  $app->engine_loader->needs_psgi_engine_compat_hack ?
    $app->engine->run($app, @_) :
      $app->engine->run( $app, $app->_finalized_psgi_app, @_ );
}

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

    my @comps = $class->locate_components($config);
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
    }

    for my $component (@comps) {
        my $instance = $class->components->{ $component } = $class->setup_component($component);
        my @expanded_components = $instance->can('expand_modules')
            ? $instance->expand_modules( $component, $config )
            : $class->expand_component_module( $component, $config );
        for my $component (@expanded_components) {
            next if $comps{$component};
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

    # XXX think about ditching this sort entirely
    my @comps = sort { length $a <=> length $b } $locator->plugins;

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

sub engine_class {
    my ($class, $requested_engine) = @_;

    if (!$class->engine_loader || $requested_engine) {
        $class->engine_loader(
            Catalyst::EngineLoader->new({
                application_name => $class,
                (defined $requested_engine
                     ? (catalyst_engine_class => $requested_engine) : ()),
            }),
        );
    }

    $class->engine_loader->catalyst_engine_class;
}

sub setup_engine {
    my ($class, $requested_engine) = @_;

    my $engine = do {
        my $loader = $class->engine_loader;

        if (!$loader || $requested_engine) {
            $loader = Catalyst::EngineLoader->new({
                application_name => $class,
                (defined $requested_engine
                     ? (requested_engine => $requested_engine) : ()),
            }),

            $class->engine_loader($loader);
        }

        $loader->catalyst_engine_class;
    };

    # Don't really setup_engine -- see _setup_psgi_app for explanation.
    return if $class->loading_psgi_file;

    Class::MOP::load_class($engine);

    if ($ENV{MOD_PERL}) {
        my $apache = $class->engine_loader->auto;

        my $meta = find_meta($class);
        my $was_immutable = $meta->is_immutable;
        my %immutable_options = $meta->immutable_options;
        $meta->make_mutable if $was_immutable;

        $meta->add_method(handler => sub {
            my $r = shift;
            my $psgi_app = $class->_finalized_psgi_app;
            $apache->call_app($r, $psgi_app);
        });

        $meta->make_immutable(%immutable_options) if $was_immutable;
    }

    $class->engine( $engine->new );

    return;
}

sub _finalized_psgi_app {
    my ($app) = @_;

    unless ($app->_psgi_app) {
        my $psgi_app = $app->_setup_psgi_app;
        $app->_psgi_app($psgi_app);
    }

    return $app->_psgi_app;
}

sub _setup_psgi_app {
    my ($app) = @_;

    for my $home (Path::Class::Dir->new($app->config->{home})) {
        my $psgi_file = $home->file(
            Catalyst::Utils::appprefix($app) . '.psgi',
        );

        next unless -e $psgi_file;

        # If $psgi_file calls ->setup_engine, it's doing so to load
        # Catalyst::Engine::PSGI. But if it does that, we're only going to
        # throw away the loaded PSGI-app and load the 5.9 Catalyst::Engine
        # anyway. So set a flag (ick) that tells setup_engine not to populate
        # $c->engine or do any other things we might regret.

        $app->loading_psgi_file(1);
        my $psgi_app = Plack::Util::load_psgi($psgi_file);
        $app->loading_psgi_file(0);

        return $psgi_app
            unless $app->engine_loader->needs_psgi_engine_compat_hack;

        warn <<"EOW";
Found a legacy Catalyst::Engine::PSGI .psgi file at ${psgi_file}.

Its content has been ignored. Please consult the Catalyst::Upgrading
documentation on how to upgrade from Catalyst::Engine::PSGI.
EOW
    }

    return $app->apply_default_middlewares($app->psgi_app);
}

=head2 $c->apply_default_middlewares

Adds the following L<Plack> middlewares to your application, since they are
useful and commonly needed:

L<Plack::Middleware::ReverseProxy>, (conditionally added based on the status
of your $ENV{REMOTE_ADDR}, and can be forced on with C<using_frontend_proxy>
or forced off with C<ignore_frontend_proxy>), L<Plack::Middleware::LighttpdScriptNameFix>
(if you are using Lighttpd), L<Plack::Middleware::IIS6ScriptNameFix> (always
applied since this middleware is smart enough to conditionally apply itself).

Additionally if we detect we are using Nginx, we add a bit of custom middleware
to solve some problems with the way that server handles $ENV{PATH_INFO} and
$ENV{SCRIPT_NAME}

=cut


sub apply_default_middlewares {
    my ($app, $psgi_app) = @_;

    $psgi_app = Plack::Middleware::Conditional->wrap(
        $psgi_app,
        builder   => sub { Plack::Middleware::ReverseProxy->wrap($_[0]) },
        condition => sub {
            my ($env) = @_;
            return if $app->config->{ignore_frontend_proxy};
            return $env->{REMOTE_ADDR} eq '127.0.0.1'
                || $app->config->{using_frontend_proxy};
        },
    );

    # If we're running under Lighttpd, swap PATH_INFO and SCRIPT_NAME
    # http://lists.scsys.co.uk/pipermail/catalyst/2006-June/008361.html
    $psgi_app = Plack::Middleware::Conditional->wrap(
        $psgi_app,
        builder   => sub { Plack::Middleware::LighttpdScriptNameFix->wrap($_[0]) },
        condition => sub {
            my ($env) = @_;
            return unless $env->{SERVER_SOFTWARE} && $env->{SERVER_SOFTWARE} =~ m!lighttpd[-/]1\.(\d+\.\d+)!;
            return unless $1 < 4.23;
            1;
        },
    );

    # we're applying this unconditionally as the middleware itself already makes
    # sure it doesn't fuck things up if it's not running under one of the right
    # IIS versions
    $psgi_app = Plack::Middleware::IIS6ScriptNameFix->wrap($psgi_app);

    return $psgi_app;
}

=head2 $c->psgi_app

Returns a PSGI application code reference for the catalyst application
C<$c>. This is the bare application without any middlewares
applied. C<${myapp}.psgi> is not taken into account.

This is what you want to be using to retrieve the PSGI application code
reference of your Catalyst application for use in F<.psgi> files.

=cut

sub psgi_app {
    my ($app) = @_;
    return $app->engine->build_psgi_app($app);
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
import list.

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
        $class->log->warn( "$plugin inherits from 'Catalyst::Component' - this is deprecated and will not work in 5.81" )
            if $plugin->isa( 'Catalyst::Component' );
        $proto->_plugins->{$plugin} = 1;
        unless ($instant) {
            my $meta = Class::MOP::get_metaclass_by_name($class);
            $meta->superclasses($plugin, $meta->superclasses);
        }
        return $class;
    }

    sub setup_plugins {
        my ( $class, $plugins ) = @_;

        $class->_plugins( {} ) unless $class->_plugins;
        $plugins = Data::OptList::mkopt($plugins || []);

        my @plugins = map {
            [ Catalyst::Utils::resolve_namespace(
                  $class . '::Plugin',
                  'Catalyst::Plugin', $_->[0]
              ),
              $_->[1],
            ]
         } @{ $plugins };

        for my $plugin ( reverse @plugins ) {
            Class::MOP::load_class($plugin->[0], $plugin->[1]);
            my $meta = find_meta($plugin->[0]);
            next if $meta && $meta->isa('Moose::Meta::Role');

            $class->_register_plugin($plugin->[0]);
        }

        my @roles =
            map  { $_->[0]->name, $_->[1] }
            grep { blessed($_->[0]) && $_->[0]->isa('Moose::Meta::Role') }
            map  { [find_meta($_->[0]), $_->[1]] }
            @plugins;

        Moose::Util::apply_all_roles(
            $class => @roles
        ) if @roles;
    }
}

=head2 $c->stack

Returns an arrayref of the internal execution stack (actions that are
currently executing).

=head2 $c->stats

Returns the current timing statistics object. By default Catalyst uses
L<Catalyst::Stats|Catalyst::Stats>, but can be set otherwise with
L<< stats_class|/"$c->stats_class" >>.

Even if L<< -Stats|/"-Stats" >> is not enabled, the stats object is still
available. By enabling it with C< $c->stats->enabled(1) >, it can be used to
profile explicitly, although MyApp.pm still won't profile nor output anything
by itself.

=head2 $c->stats_class

Returns or sets the stats (timing statistics) class. L<Catalyst::Stats|Catalyst::Stats> is used by default.

=head2 $c->use_stats

Returns 1 when L<< stats collection|/"-Stats" >> is enabled.

Note that this is a static method, not an accessor and should be overridden
by declaring C<sub use_stats { 1 }> in your MyApp.pm, not by calling C<< $c->use_stats(1) >>.

=cut

sub use_stats { 0 }


=head2 $c->write( $data )

Writes $data to the output stream. When using this method directly, you
will need to manually set the C<Content-Length> header to the length of
your output data, if known.

=cut

sub write {
    my $c = shift;

    # Finalize headers if someone manually writes output (for compat)
    $c->finalize_headers;

    return $c->response->write( @_ );
}

=head2 version

Returns the Catalyst version number. Mostly useful for "powered by"
messages in template systems.

=cut

sub version { return $Catalyst::VERSION }

=head1 CONFIGURATION

There are a number of 'base' config variables which can be set:

=over

=item *

C<default_model> - The default model picked if you say C<< $c->model >>. See L<< /$c->model($name) >>.

=item *

C<default_view> - The default view to be rendered or returned when C<< $c->view >> is called. See L<< /$c->view($name) >>.

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
the upload) before actually receiving all the data. See L</ON-DEMAND PARSER>

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

C<use_request_uri_for_path> - Controls if the C<REQUEST_URI> or C<PATH_INFO> environment
variable should be used for determining the request path. 

Most web server environments pass the requested path to the application using environment variables,
from which Catalyst has to reconstruct the request base (i.e. the top level path to / in the application,
exposed as C<< $c->request->base >>) and the request path below that base.

There are two methods of doing this, both of which have advantages and disadvantages. Which method is used
is determined by the C<< $c->config(use_request_uri_for_path) >> setting (which can either be true or false).

=over

=item use_request_uri_for_path => 0

This is the default (and the) traditional method that Catalyst has used for determining the path information.
The path is generated from a combination of the C<PATH_INFO> and C<SCRIPT_NAME> environment variables.
The allows the application to behave correctly when C<mod_rewrite> is being used to redirect requests
into the application, as these variables are adjusted by mod_rewrite to take account for the redirect.

However this method has the major disadvantage that it is impossible to correctly decode some elements
of the path, as RFC 3875 says: "C<< Unlike a URI path, the PATH_INFO is not URL-encoded, and cannot
contain path-segment parameters. >>" This means PATH_INFO is B<always> decoded, and therefore Catalyst
can't distinguish / vs %2F in paths (in addition to other encoded values).

=item use_request_uri_for_path => 1

This method uses the C<REQUEST_URI> and C<SCRIPT_NAME> environment variables. As C<REQUEST_URI> is never
decoded, this means that applications using this mode can correctly handle URIs including the %2F character
(i.e. with C<AllowEncodedSlashes> set to C<On> in Apache).

Given that this method of path resolution is provably more correct, it is recommended that you use
this unless you have a specific need to deploy your application in a non-standard environment, and you are
aware of the implications of not being able to handle encoded URI paths correctly.

However it also means that in a number of cases when the app isn't installed directly at a path, but instead
is having paths rewritten into it (e.g. as a .cgi/fcgi in a public_html directory, with mod_rewrite in a
.htaccess file, or when SSI is used to rewrite pages into the app, or when sub-paths of the app are exposed
at other URIs than that which the app is 'normally' based at with C<mod_rewrite>), the resolution of
C<< $c->request->base >> will be incorrect.

=back

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

    MyApp->config(ignore_frontend_proxy => 0);

=head2 Note about psgi files

Note that if you supply your own .psgi file, calling
C<< MyApp->psgi_app(@_); >>, then B<this will not happen automatically>.

You either need to apply L<Plack::Middleware::ReverseProxy> yourself
in your psgi, for example:

    builder {
        enable "Plack::Middleware::ReverseProxy";
        MyApp->psgi_app
    };

This will unconditionally add the ReverseProxy support, or you need to call
C<< $app = MyApp->apply_default_middlewares($app) >> (to conditionally
apply the support depending upon your config).

See L<Catalyst::PSGI> for more information.

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

dhoss: Devin Austin <dhoss@cpan.org>

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

Octavian Rasnita

omega: Andreas Marienborg

Oleg Kostyuk <cub.uanic@gmail.com>

phaylon: Robert Sedlacek <phaylon@dunkelheit.at>

rafl: Florian Ragwitz <rafl@debian.org>

random: Roland Lammel <lammel@cpan.org>

Robert Sedlacek C<< <rs@474.at> >>

SpiceMan: Marcel Montes

sky: Arthur Bergman

szbalint: Balint Szilakszi <szbalint@cpan.org>

t0m: Tomas Doran <bobtfish@bobtfish.net>

Ulf Edvinsson

Viljo Marrandi C<vilts@yahoo.com>

Will Hawes C<info@whawes.co.uk>

willert: Sebastian Willert <willert@cpan.org>

wreis: Wallace Reis <wallace@reis.org.br>

Yuval Kogman, C<nothingmuch@woobling.org>

rainboxx: Matthias Dietrich, C<perl@rainboxx.de>

dd070: Dhaval Dhanani <dhaval070@gmail.com>

=head1 COPYRIGHT

Copyright (c) 2005, the above named PROJECT FOUNDER and CONTRIBUTORS.

=head1 LICENSE

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

no Moose;

__PACKAGE__->meta->make_immutable;

1;
