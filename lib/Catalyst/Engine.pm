package Catalyst::Engine;

use strict;
use base qw/Class::Data::Inheritable Class::Accessor::Fast/;
use UNIVERSAL::require;
use Data::Dumper;
use HTML::Entities;
use HTTP::Headers;
use Memoize;
use Time::HiRes qw/gettimeofday tv_interval/;
use Tree::Simple;
use Tree::Simple::Visitor::FindByPath;
use Catalyst::Request;
use Catalyst::Response;

require Module::Pluggable::Fast;

$Data::Dumper::Terse = 1;

__PACKAGE__->mk_classdata($_) for qw/actions components tree/;
__PACKAGE__->mk_accessors(qw/request response state/);

__PACKAGE__->actions(
    { plain => {}, private => {}, regex => {}, compiled => {}, reverse => {} }
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

=item $c->action( $name => $coderef, ... )

Add one or more actions.

    $c->action( '!foo' => sub { $_[1]->res->output('Foo!') } );

It also automatically calls setup() if needed.

See L<Catalyst::Manual::Intro> for more informations about actions.

=cut

sub action {
    my $self = shift;
    $self->setup unless $self->components;
    $self->actions( {} ) unless $self->actions;
    my $action;
    $_[1] ? ( $action = {@_} ) : ( $action = shift );
    if ( ref $action eq 'HASH' ) {
        while ( my ( $name, $code ) = each %$action ) {
            $self->set_action( $name, $code, caller(0) );
        }
    }
    return 1;
}

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

=item $c->errors

=item $c->errors($error, ...)

=item $c->errors($arrayref)

Returns an arrayref containing errors messages.

    my @errors = @{ $c->errors };

Add a new error.

    $c->errors('Something bad happened');

=cut

sub errors {
    my $c = shift;
    my $errors = ref $_[0] eq 'ARRAY' ? $_[0] : [@_];
    push @{ $c->{errors} }, @$errors;
    return $c->{errors};
}

=item $c->finalize

Finalize request.

=cut

sub finalize {
    my $c = shift;

    if ( my $location = $c->res->redirect ) {
        $c->log->debug(qq/Redirecting to "$location"/) if $c->debug;
        $c->res->headers->header( Location => $location );
        $c->res->status(302);
    }

    if ( !$c->res->output || $#{ $c->errors } >= 0 ) {
        $c->res->headers->content_type('text/html');
        my $name = $c->config->{name} || 'Catalyst Application';
        my ( $title, $errors, $infos );
        if ( $c->debug ) {
            $errors = join '<br/>', @{ $c->errors };
            $errors ||= 'No output';
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
            $title  = $name;
            $errors = '';
            $infos  = <<"";
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
        $c->res->{output} = <<"";
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
            div.errors {
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
            <div class="errors">$errors</div>
            <div class="infos">$infos</div>
            <div class="name">$name</div>
        </div>
    </body>
</html>

    }
    $c->res->headers->content_length( length $c->res->output );
    my $status = $c->finalize_headers;
    $c->finalize_output;
    return $status;
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

Forward processing to a private/public action or a method from a class.
If you define a class without method it will default to process().

    $c->forward('!foo');
    $c->forward('index.html');
    $c->forward(qw/MyApp::Model::CDBI::Foo do_stuff/);
    $c->forward('MyApp::View::TT');

=cut

sub forward {
    my $c       = shift;
    my $command = shift;
    $c->state(0);
    unless ($command) {
        $c->log->debug('Nothing to forward to') if $c->debug;
        return 0;
    }
    my $caller = caller(0);
    if ( $command =~ /^\?(.*)$/ ) {
        $command = $1;
        $command = _prefix( $caller, $command );
    }
    my $namespace = '';
    if ( $command =~ /^\!/ ) {
        $namespace = _class2prefix($caller);
    }
    my $results = $c->get_action( $command, $namespace );
    if ( @{$results} ) {
        unless ( $command =~ /^\!/ ) {
            $results = [ pop @{$results} ];
            if ( $results->[0]->[2] ) {
                $c->log->debug(qq/Couldn't forward "$command" to regex action/)
                  if $c->debug;
                return 0;
            }
        }
    }
    else {
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
        my ( $class, $code ) = @{ $result->[0] };
        $class = $c->comp->{$class} || $class;
        $c->state( $c->process( $class, $code ) );
    }
    return $c->state;
}

=item $c->get_action( $action, $namespace )

Get an action in a given namespace.

=cut

sub get_action {
    my ( $c, $action, $namespace ) = @_;
    $namespace ||= '';
    if ( $action =~ /^\!(.*)/ ) {
        $action = $1;
        my $parent = $c->tree;
        my @results;
        my $result = $c->actions->{private}->{ $parent->getUID }->{$action};
        push @results, [$result] if $result;
        my $visitor = Tree::Simple::Visitor::FindByPath->new;
        my $local;
        for my $part ( split '/', $namespace ) {
            $local = undef;
            $visitor->setSearchPath($part);
            $parent->accept($visitor);
            my $child = $visitor->getResult;
            my $uid   = $child->getUID if $child;
            my $match = $c->actions->{private}->{$uid}->{$action} if $uid;
            return [ [$match] ] if ( $match && $match =~ /^?.*/ );
            $local = $c->actions->{private}->{$uid}->{"?$action"} if $uid;
            push @results, [$match] if $match;
            $parent = $child if $child;
        }
        return [ [$local] ] if $local;
        return \@results;
    }
    elsif ( my $p = $c->actions->{plain}->{$action} ) { return [ [$p] ] }
    elsif ( my $r = $c->actions->{regex}->{$action} ) { return [ [$r] ] }
    else {
        for my $regex ( keys %{ $c->actions->{compiled} } ) {
            my $name = $c->actions->{compiled}->{$regex};
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

sub handler ($$) {
    my ( $class, $r ) = @_;

    # Always expect worst case!
    my $status = -1;
    eval {
        my $handler = sub {
            my $c         = $class->prepare($r);
            my $action    = $c->req->action;
            my $namespace = '';
            $namespace = join '/', @{ $c->req->args } if $action eq '!default';
            unless ($namespace) {
                if ( my $result = $c->get_action($action) ) {
                    $namespace = _class2prefix( $result->[0]->[0]->[0] );
                }
            }
            my $results = $c->get_action( $action, $namespace );
            if ( @{$results} ) {
                for my $begin ( @{ $c->get_action( '!begin', $namespace ) } ) {
                    $c->state( $c->process( @{ $begin->[0] } ) );
                }
                for my $result ( @{ $c->get_action( $action, $namespace ) } ) {
                    $c->state( $c->process( @{ $result->[0] } ) );
                }
                for my $end ( @{ $c->get_action( '!end', $namespace ) } ) {
                    $c->state( $c->process( @{ $end->[0] } ) );
                }
            }
            else {
                my $path  = $c->req->path;
                my $error = $path
                  ? qq/Unknown resource "$path"/
                  : "No default action defined";
                $c->log->error($error) if $c->debug;
                $c->errors($error);
            }
            return $c->finalize;
        };
        if ( $class->debug ) {
            my $elapsed;
            ( $elapsed, $status ) = $class->benchmark($handler);
            $elapsed = sprintf '%f', $elapsed;
            my $av = sprintf '%.3f', 1 / $elapsed;
            $class->log->info( "Request took $elapsed" . "s ($av/s)" );
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

Turns the engine-specific request (Apache, CGI...) into a Catalyst context.

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
        $c->log->debug('********************************');
        $c->log->debug("* Request $COUNT ($av/s) [$$]");
        $c->log->debug('********************************');
        $c->res->headers->header( 'X-Catalyst' => $Catalyst::VERSION );
    }
    $c->prepare_request($r);
    $c->prepare_path;
    $c->prepare_cookies;
    $c->prepare_headers;
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
        my @params;
        for my $key ( keys %{ $c->req->params } ) {
            my $value = $c->req->params->{$key} || '';
            push @params, "$key=$value";
        }
        $c->log->debug( 'Parameters are "' . join( ' ', @params ) . '"' );
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
                $c->log->debug(qq/Requested action "$path" matched "$match"/)
                  if $c->debug;
                $c->log->debug(
                    'Snippets are "' . join( ' ', @snippets ) . '"' )
                  if ( $c->debug && @snippets );
                $c->req->action($match);
                $c->req->snippets( \@snippets );
            }
            else {
                $c->req->action($path);
                $c->log->debug(qq/Requested action "$path"/) if $c->debug;
            }
            $c->req->match($path);
            last;
        }
        unshift @args, pop @path;
    }
    unless ( $c->req->action ) {
        $c->req->action('!default');
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

sub prepare_cookies { }

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

=item $c->process($class, $coderef)

Process a coderef in given class and catch exceptions.
Errors are available via $c->errors.

=cut

sub process {
    my ( $c, $class, $code ) = @_;
    my $status;
    eval {
        if ( $c->debug )
        {
            my $action = $c->actions->{reverse}->{"$code"} || "$code";
            my $elapsed;
            ( $elapsed, $status ) =
              $c->benchmark( $code, $class, $c, @{ $c->req->args } );
            $c->log->info( sprintf qq/Processing "$action" took %fs/, $elapsed )
              if $c->debug;
        }
        else { $status = &$code( $class, $c, @{ $c->req->args } ) }
    };
    if ( my $error = $@ ) {
        chomp $error;
        $error = qq/Caught exception "$error"/;
        $c->log->error($error);
        $c->errors($error) if $c->debug;
        return 0;
    }
    return $status;
}

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

=item $c->set_action( $action, $code, $namespace )

Set an action in a given namespace.

=cut

sub set_action {
    my ( $c, $action, $code, $namespace ) = @_;
    my $prefix = '';
    if ( $action =~ /^\?(.*)$/ ) {
        my $prefix = $1 || '';
        $action = $2;
        $action = $prefix . _prefix( $namespace, $action );
        $c->actions->{plain}->{$action} = [ $namespace, $code ];
    }
    elsif ( $action =~ /^\/(.*)\/$/ ) {
        my $regex = $1;
        $c->actions->{compiled}->{qr#$regex#} = $action;
        $c->actions->{regex}->{$action} = [ $namespace, $code ];
    }
    elsif ( $action =~ /^\!(.*)$/ ) {
        $action = $1;
        my $parent  = $c->tree;
        my $visitor = Tree::Simple::Visitor::FindByPath->new;
        $prefix = _class2prefix($namespace);
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
        $c->actions->{private}->{$uid}->{$action} = [ $namespace, $code ];
        $action = "!$action";
    }
    else { $c->actions->{plain}->{$action} = [ $namespace, $code ] }
    my $reverse = $prefix ? "$action ($prefix)" : $action;
    $c->actions->{reverse}->{"$code"} = $reverse;
    $c->log->debug(qq/"$namespace" defined "$action" as "$code"/) if $c->debug;
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
    $self->components( {} );
    for my $component ( $self->_components($self) ) {
        $self->components->{ ref $component } = $component;
    }
    $self->log->debug( 'Initialized components "'
          . join( ' ', keys %{ $self->components } )
          . '"' )
      if $self->debug;
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
    warn "$class - $name - $prefix";
    $name = "$prefix/$name" if $prefix;
    return $name;
}

sub _class2prefix {
    my $class = shift || '';
    $class =~ /^.*::([MVC]|Model|View|Controller)?::(.*)$/;
    my $prefix = lc $2 || '';
    $prefix =~ s/\:\:/\//g;
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
