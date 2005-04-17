package Catalyst::Engine;

use strict;
use base qw/Class::Data::Inheritable Class::Accessor::Fast/;
use attributes ();
use UNIVERSAL::require;
use CGI::Cookie;
use Data::Dumper;
use HTML::Entities;
use HTTP::Headers;
use Time::HiRes qw/gettimeofday tv_interval/;
use Text::ASCIITable;
use Catalyst::Request;
use Catalyst::Request::Upload;
use Catalyst::Response;

require Module::Pluggable::Fast;

# For pretty dumps
$Data::Dumper::Terse = 1;

__PACKAGE__->mk_classdata('components');
__PACKAGE__->mk_accessors(qw/request response state/);

*comp = \&component;
*req  = \&request;
*res  = \&response;

# For backwards compatibility
*finalize_output = \&finalize_body;

# For statistics
our $COUNT = 1;
our $START = time;

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

        unless ( ref $error ) {
            chomp $error;
            $error = qq/Caught exception "$error"/;
        }

        $c->log->error($error);
        $c->error($error);
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
        $c->response->status(302) if $c->response->status !~ /^3\d\d$/;
    }

    if ( $#{ $c->error } >= 0 ) {
        $c->finalize_error;
    }

    if ( !$c->response->body && $c->response->status !~ /^(1|3)\d\d$/ ) {
        $c->finalize_error;
    }

    if ( $c->response->body && !$c->response->content_length ) {
        use bytes;    # play safe with a utf8 aware perl
        $c->response->content_length( length $c->response->body );
    }

    my $status = $c->finalize_headers;
    $c->finalize_body;
    return $status;
}

=item $c->finalize_body

Finalize body.

=cut

sub finalize_body { }

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
    $c->res->body( <<"" );
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

=item $c->handler( $class, $engine )

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
            $c->dispatch;
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

            for my $stat (@stats) { $t->addRow( $stat->[0], $stat->[1] ) }
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
    my ( $class, $engine ) = @_;

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

    $c->prepare_request($engine);
    $c->prepare_path;
    $c->prepare_headers;
    $c->prepare_cookies;
    $c->prepare_connection;
    $c->prepare_action;

    my $method   = $c->req->method   || '';
    my $path     = $c->req->path     || '';
    my $hostname = $c->req->hostname || '';
    my $address  = $c->req->address  || '';

    $c->log->debug(qq/"$method" request for "$path" from $hostname($address)/)
      if $c->debug;

    if ( $c->request->method eq 'POST' and $c->request->content_length ) {

        if ( $c->req->content_type eq 'application/x-www-form-urlencoded' ) {
            $c->prepare_parameters;
        }
        elsif ( $c->req->content_type eq 'multipart/form-data' ) {
            $c->prepare_parameters;
            $c->prepare_uploads;
        }
        else {
            $c->prepare_body;
        }
    }

    if ( $c->request->method eq 'GET' ) {
        $c->prepare_parameters;
    }

    if ( $c->debug && keys %{ $c->req->params } ) {
        my $t = Text::ASCIITable->new;
        $t->setCols( 'Key', 'Value' );
        $t->setColWidth( 'Key',   37, 1 );
        $t->setColWidth( 'Value', 36, 1 );
        for my $key ( keys %{ $c->req->params } ) {
            my $value = $c->req->params->{$key} || '';
            $t->addRow( $key, $value );
        }
        $c->log->debug( 'Parameters are', $t->draw );
    }

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

=item $c->prepare_body

Prepare message body.

=cut

sub prepare_body { }

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
        die qq/Couldn't load components "$error"/;
    }

    $self->components( {} );
    my @comps;
    for my $comp ( $self->_components($self) ) {
        $self->components->{ ref $comp } = $comp;
        push @comps, $comp;
    }

    my $t = Text::ASCIITable->new( { hide_HeadRow => 1, hide_HeadLine => 1 } );
    $t->setCols('Class');
    $t->setColWidth( 'Class', 75, 1 );
    $t->addRow($_) for keys %{ $self->components };
    $self->log->debug( 'Loaded components', $t->draw )
      if ( @{ $t->{tbl_rows} } && $self->debug );

    $self->setup_actions( [ $self, @comps ] );
}

=item $c->state

Contains the return value of the last executed action.

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

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
