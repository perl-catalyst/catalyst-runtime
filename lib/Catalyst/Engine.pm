package Catalyst::Engine;

use strict;
use base qw/Class::Data::Inheritable Class::Accessor::Fast/;
use UNIVERSAL::require;
use CGI::Cookie;
use Data::Dumper;
use HTML::Entities;
use HTTP::Headers;
use Memoize;
use Time::HiRes qw/gettimeofday tv_interval/;
use Text::ASCIITable;
use Text::ASCIITable::Wrap 'wrap';
use Tree::Simple;
use Tree::Simple::Visitor::FindByPath;
use Catalyst::Request;
use Catalyst::Response;

require Module::Pluggable::Fast;

$Data::Dumper::Terse = 1;

__PACKAGE__->mk_classdata($_) for qw/actions components tree/;
__PACKAGE__->mk_accessors(qw/request response state/);

__PACKAGE__->actions(
    { plain => {}, private => {}, regex => {}, compiled => [], reverse => {} }
);
__PACKAGE__->tree( Tree::Simple->new( 0, Tree::Simple->ROOT ) );

*comp = \&component;
*req  = \&request;
*res  = \&response;

our $COUNT = 1;
our $START = time;

memoize('_class2prefix');

=head1 NAME

Catalyst::Engine - The Catalyst Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

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

=item $c->comp($name)

=item $c->component($name)

Get a component object by name.

    $c->comp('MyApp::Model::MyModel')->do_stuff;

Regex search for a component.

    $c->comp('mymodel')->do_stuff;

=cut

sub component {
    my ( $c, $name ) = @_;
    if ( my $component = $c->components->{$name} ) {
        return $component;
    }
    else {
        for my $component ( keys %{ $c->components } ) {
            return $c->components->{$component} if $component =~ /$name/i;
        }
    }
}

=item $c->error

=item $c->error($error, ...)

=item $c->error($arrayref)

Returns an arrayref containing error messages.

    my @error = @{ $c->error };

Add a new error.

    $c->error('Something bad happened');

=cut

sub error {
    my $c = shift;
    my $error = ref $_[0] eq 'ARRAY' ? $_[0] : [@_];
    push @{ $c->{error} }, @$error;
    return $c->{error};
}

=item $c->execute($class, $coderef)

Execute a coderef in given class and catch exceptions.
Errors are available via $c->error.

=cut

sub execute {
    my ( $c, $class, $code ) = @_;
    $class = $c->comp($class) || $class;
    $c->state(0);
    my $callsub = ( caller(1) )[3];
    eval {
        if ( $c->debug )
        {
            my $action = $c->actions->{reverse}->{"$code"};
            $action = "/$action" unless $action =~ /\-\>/;
            $action = "-> $action" if $callsub =~ /forward$/;
            my ( $elapsed, @state ) =
              $c->benchmark( $code, $class, $c, @{ $c->req->args } );
            push @{ $c->{stats} }, [ $action, sprintf( '%fs', $elapsed ) ];
            $c->state(@state);
        }
        else { $c->state( &$code( $class, $c, @{ $c->req->args } ) ) }
    };
    if ( my $error = $@ ) {
        chomp $error;
        $error = qq/Caught exception "$error"/;
        $c->log->error($error);
        $c->error($error) if $c->debug;
        $c->state(0);
    }
    return $c->state;
}

=item $c->finalize

Finalize request.

=cut

sub finalize {
    my $c = shift;

    $c->finalize_cookies;

    if ( my $location = $c->response->redirect ) {
        $c->log->debug(qq/Redirecting to "$location"/) if $c->debug;
        $c->response->header( Location => $location );
        $c->response->status(302) if $c->response->status !~ /3\d\d$/;
    }

    if ( $#{ $c->error } >= 0 ) {
        $c->finalize_error;
    }

    if ( !$c->response->output && $c->response->status !~ /^(1|3)\d\d$/ ) {
        $c->finalize_error;
    }

    if ( $c->response->output && !$c->response->content_length ) {
        use bytes;    # play safe with a utf8 aware perl
        $c->response->content_length( length $c->response->output );
    }

    my $status = $c->finalize_headers;
    $c->finalize_output;
    return $status;
}

=item $c->finalize_cookies

Finalize cookies.

=cut

sub finalize_cookies {
    my $c = shift;

    while ( my ( $name, $cookie ) = each %{ $c->response->cookies } ) {
        my $cookie = CGI::Cookie->new(
            -name    => $name,
            -value   => $cookie->{value},
            -expires => $cookie->{expires},
            -domain  => $cookie->{domain},
            -path    => $cookie->{path},
            -secure  => $cookie->{secure} || 0
        );

        $c->res->headers->push_header( 'Set-Cookie' => $cookie->as_string );
    }
}

=item $c->finalize_error

Finalize error.

=cut

sub finalize_error {
    my $c = shift;

    $c->res->headers->content_type('text/html');
    my $name = $c->config->{name} || 'Catalyst Application';

    my ( $title, $error, $infos );
    if ( $c->debug ) {
        $error = join '<br/>', @{ $c->error };
        $error ||= 'No output';
        $title = $name = "$name on Catalyst $Catalyst::VERSION";
        my $req   = encode_entities Dumper $c->req;
        my $res   = encode_entities Dumper $c->res;
        my $stash = encode_entities Dumper $c->stash;
        $infos = <<"";
<br/>
<b><u>Request</u></b><br/>
<pre>$req</pre>
<b><u>Response</u></b><br/>
<pre>$res</pre>
<b><u>Stash</u></b><br/>
<pre>$stash</pre>

    }
    else {
        $title = $name;
        $error = '';
        $infos = <<"";
<pre>
(en) Please come back later
(de) Bitte versuchen sie es spaeter nocheinmal
(nl) Gelieve te komen later terug
(no) Vennligst prov igjen senere
(fr) Veuillez revenir plus tard
(es) Vuelto por favor mas adelante
(pt) Voltado por favor mais tarde
(it) Ritornato prego più successivamente
</pre>

        $name = '';
    }
    $c->res->output( <<"" );
<html>
<head>
    <title>$title</title>
    <style type="text/css">
        body {
            font-family: "Bitstream Vera Sans", "Trebuchet MS", Verdana,
                         Tahoma, Arial, helvetica, sans-serif;
            color: #ddd;
            background-color: #eee;
            margin: 0px;
            padding: 0px;
        }
        div.box {
            background-color: #ccc;
            border: 1px solid #aaa;
            padding: 4px;
            margin: 10px;
            -moz-border-radius: 10px;
        }
        div.error {
            background-color: #977;
            border: 1px solid #755;
            padding: 8px;
            margin: 4px;
            margin-bottom: 10px;
            -moz-border-radius: 10px;
        }
        div.infos {
            background-color: #797;
            border: 1px solid #575;
            padding: 8px;
            margin: 4px;
            margin-bottom: 10px;
            -moz-border-radius: 10px;
        }
        div.name {
            background-color: #779;
            border: 1px solid #557;
            padding: 8px;
            margin: 4px;
            -moz-border-radius: 10px;
        }
    </style>
</head>
<body>
    <div class="box">
        <div class="error">$error</div>
        <div class="infos">$infos</div>
        <div class="name">$name</div>
    </div>
</body>
</html>

}

=item $c->finalize_headers

Finalize headers.

=cut

sub finalize_headers { }

=item $c->finalize_output

Finalize output.

=cut

sub finalize_output { }

=item $c->forward($command)

Forward processing to a private action or a method from a class.
If you define a class without method it will default to process().

    $c->forward('/foo');
    $c->forward('index');
    $c->forward(qw/MyApp::Model::CDBI::Foo do_stuff/);
    $c->forward('MyApp::View::TT');

=cut

sub forward {
    my $c       = shift;
    my $command = shift;
    unless ($command) {
        $c->log->debug('Nothing to forward to') if $c->debug;
        return 0;
    }
    my $caller    = caller(0);
    my $namespace = '/';
    if ( $command =~ /^\// ) {
        $command =~ /^(.*)\/(\w+)$/;
        $namespace = $1 || '/';
        $command = $2;
    }
    else { $namespace = _class2prefix($caller) || '/' }
    my $results = $c->get_action( $command, $namespace );
    unless ( @{$results} ) {
        my $class = $command;
        if ( $class =~ /[^\w\:]/ ) {
            $c->log->debug(qq/Couldn't forward to "$class"/) if $c->debug;
            return 0;
        }
        my $method = shift || 'process';
        if ( my $code = $class->can($method) ) {
            $c->actions->{reverse}->{"$code"} = "$class->$method";
            $results = [ [ [ $class, $code ] ] ];
        }
        else {
            $c->log->debug(qq/Couldn't forward to "$class->$method"/)
              if $c->debug;
            return 0;
        }
    }
    for my $result ( @{$results} ) {
        $c->state( $c->execute( @{ $result->[0] } ) );
    }
    return $c->state;
}

=item $c->get_action( $action, $namespace )

Get an action in a given namespace.

=cut

sub get_action {
    my ( $c, $action, $namespace ) = @_;
    return [] unless $action;
    $namespace ||= '';
    if ($namespace) {
        $namespace = '' if $namespace eq '/';
        my $parent = $c->tree;
        my @results;
        my $result = $c->actions->{private}->{ $parent->getUID }->{$action};
        push @results, [$result] if $result;
        my $visitor = Tree::Simple::Visitor::FindByPath->new;
        for my $part ( split '/', $namespace ) {
            $visitor->setSearchPath($part);
            $parent->accept($visitor);
            my $child = $visitor->getResult;
            my $uid   = $child->getUID if $child;
            my $match = $c->actions->{private}->{$uid}->{$action} if $uid;
            push @results, [$match] if $match;
            $parent = $child if $child;
        }
        return \@results;
    }
    elsif ( my $p = $c->actions->{plain}->{$action} ) { return [ [$p] ] }
    elsif ( my $r = $c->actions->{regex}->{$action} ) { return [ [$r] ] }
    else {
        for my $i ( 0 .. $#{ $c->actions->{compiled} } ) {
            my $name  = $c->actions->{compiled}->[$i]->[0];
            my $regex = $c->actions->{compiled}->[$i]->[1];
            if ( $action =~ $regex ) {
                my @snippets;
                for my $i ( 1 .. 9 ) {
                    no strict 'refs';
                    last unless ${$i};
                    push @snippets, ${$i};
                }
                return [ [ $c->actions->{regex}->{$name}, $name, \@snippets ] ];
            }
        }
    }
    return [];
}

=item $c->handler( $class, $r )

Handles the request.

=cut

sub handler {
    my ( $class, $engine ) = @_;

    # Always expect worst case!
    my $status = -1;
    eval {
        my @stats = ();
        my $handler = sub {
            my $c = $class->prepare($engine);
            $c->{stats} = \@stats;
            my $action    = $c->req->action;
            my $namespace = '';
            $namespace = ( join( '/', @{ $c->req->args } ) || '/' )
              if $action eq 'default';
            unless ($namespace) {
                if ( my $result = $c->get_action($action) ) {
                    $namespace = _class2prefix( $result->[0]->[0]->[0] );
                }
            }
            my $default = $action eq 'default' ? $namespace : undef;
            my $results = $c->get_action( $action, $default );
            $namespace ||= '/';
            if ( @{$results} ) {
                for my $begin ( @{ $c->get_action( 'begin', $namespace ) } ) {
                    $c->state( $c->execute( @{ $begin->[0] } ) );
                }
                if ( my $action = $c->req->action ) {
                    for my $result (
                        @{ $c->get_action( $action, $default ) }[-1] )
                    {
                        $c->state( $c->execute( @{ $result->[0] } ) );
                        last unless $default;
                    }
                }
                for my $end ( reverse @{ $c->get_action( 'end', $namespace ) } )
                {
                    $c->state( $c->execute( @{ $end->[0] } ) );
                }
            }
            else {
                my $path  = $c->req->path;
                my $error = $path
                  ? qq/Unknown resource "$path"/
                  : "No default action defined";
                $c->log->error($error) if $c->debug;
                $c->error($error);
            }
            return $c->finalize;
        };
        if ( $class->debug ) {
            my $elapsed;
            ( $elapsed, $status ) = $class->benchmark($handler);
            $elapsed = sprintf '%f', $elapsed;
            my $av = sprintf '%.3f', 1 / $elapsed;
            my $t = Text::ASCIITable->new;
            $t->setCols( 'Action', 'Time' );
            $t->setColWidth( 'Action', 64, 1 );
            $t->setColWidth( 'Time',   9,  1 );

            for my $stat (@stats) {
                $t->addRow( wrap( $stat->[0], 64 ), wrap( $stat->[1], 9 ) );
            }
            $class->log->info( "Request took $elapsed" . "s ($av/s)",
                $t->draw );
        }
        else { $status = &$handler }
    };
    if ( my $error = $@ ) {
        chomp $error;
        $class->log->error(qq/Caught exception in engine "$error"/);
    }
    $COUNT++;
    return $status;
}

=item $c->prepare($r)

Turns the engine-specific request( Apache, CGI ... )
into a Catalyst context .

=cut

sub prepare {
    my ( $class, $r ) = @_;
    my $c = bless {
        request => Catalyst::Request->new(
            {
                arguments  => [],
                cookies    => {},
                headers    => HTTP::Headers->new,
                parameters => {},
                snippets   => [],
                uploads    => {}
            }
        ),
        response => Catalyst::Response->new(
            { cookies => {}, headers => HTTP::Headers->new, status => 200 }
        ),
        stash => {},
        state => 0
    }, $class;
    if ( $c->debug ) {
        my $secs = time - $START || 1;
        my $av = sprintf '%.3f', $COUNT / $secs;
        $c->log->debug('**********************************');
        $c->log->debug("* Request $COUNT ($av/s) [$$]");
        $c->log->debug('**********************************');
        $c->res->headers->header( 'X-Catalyst' => $Catalyst::VERSION );
    }
    $c->prepare_request($r);
    $c->prepare_path;
    $c->prepare_headers;
    $c->prepare_cookies;
    $c->prepare_connection;
    my $method   = $c->req->method   || '';
    my $path     = $c->req->path     || '';
    my $hostname = $c->req->hostname || '';
    my $address  = $c->req->address  || '';
    $c->log->debug(qq/"$method" request for "$path" from $hostname($address)/)
      if $c->debug;
    $c->prepare_action;
    $c->prepare_parameters;

    if ( $c->debug && keys %{ $c->req->params } ) {
        my $t = Text::ASCIITable->new;
        $t->setCols( 'Key', 'Value' );
        $t->setColWidth( 'Key',   37, 1 );
        $t->setColWidth( 'Value', 36, 1 );
        for my $key ( keys %{ $c->req->params } ) {
            my $value = $c->req->params->{$key} || '';
            $t->addRow( wrap( $key, 37 ), wrap( $value, 36 ) );
        }
        $c->log->debug( 'Parameters are', $t->draw );
    }
    $c->prepare_uploads;
    return $c;
}

=item $c->prepare_action

Prepare action.

=cut

sub prepare_action {
    my $c    = shift;
    my $path = $c->req->path;
    my @path = split /\//, $c->req->path;
    $c->req->args( \my @args );
    while (@path) {
        $path = join '/', @path;
        if ( my $result = ${ $c->get_action($path) }[0] ) {

            # It's a regex
            if ($#$result) {
                my $match    = $result->[1];
                my @snippets = @{ $result->[2] };
                $c->log->debug(
                    qq/Requested action is "$path" and matched "$match"/)
                  if $c->debug;
                $c->log->debug(
                    'Snippets are "' . join( ' ', @snippets ) . '"' )
                  if ( $c->debug && @snippets );
                $c->req->action($match);
                $c->req->snippets( \@snippets );
            }
            else {
                $c->req->action($path);
                $c->log->debug(qq/Requested action is "$path"/) if $c->debug;
            }
            $c->req->match($path);
            last;
        }
        unshift @args, pop @path;
    }
    unless ( $c->req->action ) {
        $c->req->action('default');
        $c->req->match('');
    }
    $c->log->debug( 'Arguments are "' . join( '/', @args ) . '"' )
      if ( $c->debug && @args );
}

=item $c->prepare_connection

Prepare connection.

=cut

sub prepare_connection { }

=item $c->prepare_cookies

Prepare cookies.

=cut

sub prepare_cookies {
    my $c = shift;

    if ( my $header = $c->request->header('Cookie') ) {
        $c->req->cookies( { CGI::Cookie->parse($header) } );
    }
}

=item $c->prepare_headers

Prepare headers.

=cut

sub prepare_headers { }

=item $c->prepare_parameters

Prepare parameters.

=cut

sub prepare_parameters { }

=item $c->prepare_path

Prepare path and base.

=cut

sub prepare_path { }

=item $c->prepare_request

Prepare the engine request.

=cut

sub prepare_request { }

=item $c->prepare_uploads

Prepare uploads.

=cut

sub prepare_uploads { }

=item $c->run

Starts the engine.

=cut

sub run { }

=item $c->request

=item $c->req

Returns a C<Catalyst::Request> object.

    my $req = $c->req;

=item $c->response

=item $c->res

Returns a C<Catalyst::Response> object.

    my $res = $c->res;

=item $c->set_action( $action, $code, $namespace, $attrs )

Set an action in a given namespace.

=cut

sub set_action {
    my ( $c, $method, $code, $namespace, $attrs ) = @_;

    my $prefix = _class2prefix($namespace) || '';
    my %flags;

    for my $attr ( @{$attrs} ) {
        if    ( $attr =~ /^(Local|Relative)$/ )        { $flags{local}++ }
        elsif ( $attr =~ /^(Global|Absolute)$/ )       { $flags{global}++ }
        elsif ( $attr =~ /^Path\((.+)\)$/i )           { $flags{path} = $1 }
        elsif ( $attr =~ /^Private$/i )                { $flags{private}++ }
        elsif ( $attr =~ /^(Regex|Regexp)\((.+)\)$/i ) { $flags{regex} = $2 }
    }

    return unless keys %flags;

    my $parent  = $c->tree;
    my $visitor = Tree::Simple::Visitor::FindByPath->new;
    for my $part ( split '/', $prefix ) {
        $visitor->setSearchPath($part);
        $parent->accept($visitor);
        my $child = $visitor->getResult;
        unless ($child) {
            $child = $parent->addChild( Tree::Simple->new($part) );
            $visitor->setSearchPath($part);
            $parent->accept($visitor);
            $child = $visitor->getResult;
        }
        $parent = $child;
    }
    my $uid = $parent->getUID;
    $c->actions->{private}->{$uid}->{$method} = [ $namespace, $code ];
    my $forward = $prefix ? "$prefix/$method" : $method;

    if ( $flags{path} ) {
        $flags{path} =~ s/^\w+//;
        $flags{path} =~ s/\w+$//;
        if ( $flags{path} =~ /^'(.*)'$/ ) { $flags{path} = $1 }
        if ( $flags{path} =~ /^"(.*)"$/ ) { $flags{path} = $1 }
    }
    if ( $flags{regex} ) {
        $flags{regex} =~ s/^\w+//;
        $flags{regex} =~ s/\w+$//;
        if ( $flags{regex} =~ /^'(.*)'$/ ) { $flags{regex} = $1 }
        if ( $flags{regex} =~ /^"(.*)"$/ ) { $flags{regex} = $1 }
    }

    my $reverse = $prefix ? "$prefix/$method" : $method;

    if ( $flags{local} || $flags{global} || $flags{path} ) {
        my $path = $flags{path} || $method;
        my $absolute = 0;
        if ( $path =~ /^\/(.+)/ ) {
            $path     = $1;
            $absolute = 1;
        }
        $absolute = 1 if $flags{global};
        my $name = $absolute ? $path : "$prefix/$path";
        $c->actions->{plain}->{$name} = [ $namespace, $code ];
    }
    if ( my $regex = $flags{regex} ) {
        push @{ $c->actions->{compiled} }, [ $regex, qr#$regex# ];
        $c->actions->{regex}->{$regex} = [ $namespace, $code ];
    }

    $c->actions->{reverse}->{"$code"} = $reverse;
}

=item $class->setup

Setup.

    MyApp->setup;

=cut

sub setup {
    my $self = shift;
    $self->setup_components;
    if ( $self->debug ) {
        my $name = $self->config->{name} || 'Application';
        $self->log->info("$name powered by Catalyst $Catalyst::VERSION");
    }
}

=item $class->setup_actions($component)

Setup actions for a component.

=cut

sub setup_actions {
    my ( $self, $comp ) = @_;
    $comp = ref $comp || $comp;
    for my $action ( @{ $comp->_cache } ) {
        my ( $code, $attrs ) = @{$action};
        my $name = '';
        no strict 'refs';
        my @cache = ( $comp, @{"$comp\::ISA"} );
        my %namespaces;
        while ( my $namespace = shift @cache ) {
            $namespaces{$namespace}++;
            for my $isa ( @{"$comp\::ISA"} ) {
                next if $namespaces{$isa};
                push @cache, $isa;
                $namespaces{$isa}++;
            }
        }
        for my $namespace ( keys %namespaces ) {
            for my $sym ( values %{ $namespace . '::' } ) {
                if ( *{$sym}{CODE} && *{$sym}{CODE} == $code ) {
                    $name = *{$sym}{NAME};
                    $self->set_action( $name, $code, $comp, $attrs );
                    last;
                }
            }
        }
    }
}

=item $class->setup_components

Setup components.

=cut

sub setup_components {
    my $self = shift;

    # Components
    my $class = ref $self || $self;
    eval <<"";
        package $class;
        import Module::Pluggable::Fast
          name   => '_components',
          search => [
            '$class\::Controller', '$class\::C',
            '$class\::Model',      '$class\::M',
            '$class\::View',       '$class\::V'
          ];

    if ( my $error = $@ ) {
        chomp $error;
        $self->log->error(
            qq/Couldn't initialize "Module::Pluggable::Fast", "$error"/);
    }
    $self->setup_actions($self);
    $self->components( {} );
    for my $comp ( $self->_components($self) ) {
        $self->components->{ ref $comp } = $comp;
        $self->setup_actions($comp);
    }
    my $t = Text::ASCIITable->new;
    $t->setCols('Class');
    $t->setColWidth( 'Class', 75, 1 );
    $t->addRow( wrap( $_, 75 ) ) for keys %{ $self->components };
    $self->log->debug( 'Loaded components', $t->draw )
      if ( @{ $t->{tbl_rows} } && $self->debug );
    my $actions  = $self->actions;
    my $privates = Text::ASCIITable->new;
    $privates->setCols( 'Action', 'Class', 'Code' );
    $privates->setColWidth( 'Action', 28, 1 );
    $privates->setColWidth( 'Class',  28, 1 );
    $privates->setColWidth( 'Code',   14, 1 );
    my $walker = sub {
        my ( $walker, $parent, $prefix ) = @_;
        $prefix .= $parent->getNodeValue || '';
        $prefix .= '/' unless $prefix =~ /\/$/;
        my $uid = $parent->getUID;
        for my $action ( keys %{ $actions->{private}->{$uid} } ) {
            my ( $class, $code ) = @{ $actions->{private}->{$uid}->{$action} };
            $privates->addRow(
                wrap( "$prefix$action", 28 ),
                wrap( $class,           28 ),
                wrap( $code,            14 )
            );
        }
        $walker->( $walker, $_, $prefix ) for $parent->getAllChildren;
    };
    $walker->( $walker, $self->tree, '' );
    $self->log->debug( 'Loaded private actions', $privates->draw )
      if ( @{ $privates->{tbl_rows} } && $self->debug );
    my $publics = Text::ASCIITable->new;
    $publics->setCols( 'Action', 'Class', 'Code' );
    $publics->setColWidth( 'Action', 28, 1 );
    $publics->setColWidth( 'Class',  28, 1 );
    $publics->setColWidth( 'Code',   14, 1 );

    for my $plain ( sort keys %{ $actions->{plain} } ) {
        my ( $class, $code ) = @{ $actions->{plain}->{$plain} };
        $publics->addRow(
            wrap( "/$plain", 28 ),
            wrap( $class,    28 ),
            wrap( $code,     14 )
        );
    }
    $self->log->debug( 'Loaded public actions', $publics->draw )
      if ( @{ $publics->{tbl_rows} } && $self->debug );
    my $regexes = Text::ASCIITable->new;
    $regexes->setCols( 'Action', 'Class', 'Code' );
    $regexes->setColWidth( 'Action', 28, 1 );
    $regexes->setColWidth( 'Class',  28, 1 );
    $regexes->setColWidth( 'Code',   14, 1 );
    for my $regex ( sort keys %{ $actions->{regex} } ) {
        my ( $class, $code ) = @{ $actions->{regex}->{$regex} };
        $regexes->addRow(
            wrap( $regex, 28 ),
            wrap( $class, 28 ),
            wrap( $code,  14 )
        );
    }
    $self->log->debug( 'Loaded regex actions', $regexes->draw )
      if ( @{ $regexes->{tbl_rows} } && $self->debug );
}

=item $c->stash

Returns a hashref containing all your data.

    $c->stash->{foo} ||= 'yada';
    print $c->stash->{foo};

=cut

sub stash {
    my $self = shift;
    if ( $_[0] ) {
        my $stash = $_[1] ? {@_} : $_[0];
        while ( my ( $key, $val ) = each %$stash ) {
            $self->{stash}->{$key} = $val;
        }
    }
    return $self->{stash};
}

sub _prefix {
    my ( $class, $name ) = @_;
    my $prefix = _class2prefix($class);
    $name = "$prefix/$name" if $prefix;
    return $name;
}

sub _class2prefix {
    my $class = shift || '';
    my $prefix;
    if ( $class =~ /^.*::([MVC]|Model|View|Controller)?::(.*)$/ ) {
        $prefix = lc $2;
        $prefix =~ s/\:\:/\//g;
    }
    return $prefix;
}

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
