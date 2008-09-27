package Catalyst::Engine::HTTPEngine;

# Experimental HTTP::Engine engine

# TODO:
# * Lots of copying/reference going on between HTTP::Engine req/res and Catalyst req/res
# * Body support
# * Proxy checks
# * Lots of test failures

use Moose;

use Data::Dump qw(dump);
use HTTP::Engine;
use Socket;

use constant DEBUG => $ENV{CATALYST_HTTP_DEBUG} || 0;

sub run {
    my ( $self, $class, $port, $host, $options ) = @_;

    $options ||= {};
    
    $self->{appclass} = $class;
    $self->{options}  = $options;
    
    my $addr = $host ? inet_aton($host) : INADDR_ANY;
    if ( $addr eq INADDR_ANY ) {
        require Sys::Hostname;
        $host = lc Sys::Hostname::hostname();
    }
    else {
        $host = gethostbyaddr( $addr, AF_INET ) || inet_ntoa($addr);
    }
    
    my $engine = HTTP::Engine->new(
        interface => {
            module => 'Standalone',
            args   => {
                host => inet_ntoa($addr),
                port => $port,
            },
            request_handler => sub {
                $self->handler( $_[0] );
            },
        },
    );
    
    my $url = "http://$host";
    $url .= ":$port" unless $port == 80;

    print "You can connect to your server at $url\n";
    
    $engine->run;
}

sub handler {
    my ( $self, $req ) = @_;
    
    my $res = HTTP::Engine::Response->new;
    
    # Pass control to Catalyst
    $self->{appclass}->handle_request(
        req => $req,
        res => $res,
    );

    return $res;
}

sub prepare_request {
    my ( $self, $c, %args ) = @_;
    
    $c->{_ereq} = $args{req};
    $c->{_eres} = $args{res};
}

sub prepare_connection {
    my ( $self, $c ) = @_;
    
    my $ci      = $c->{_ereq}->connection_info;
    my $request = $c->request;
    
    $request->address( $ci->{address} );
    
    # XXX proxy check
    
    $request->hostname( $ci->{address} );
    $request->protocol( $ci->{protocol} );
    $request->user( $ci->{user} );
    $request->method( $ci->{method} );
    
    # XXX $request->secure
}

sub prepare_query_parameters {
    my ( $self, $c ) = @_;
    
    my $ereq = $c->{_ereq};
    
    return unless defined $ereq->uri->query;
    
    # Check for keywords (no = signs)
    # (yes, index() is faster than a regex :))
    if ( index( $ereq->uri->query, '=' ) < 0 ) {
        $c->request->query_keywords(
            $self->unescape_uri( $ereq->uri->query )
        );
        return;
    }
    
    $c->request->query_parameters( $ereq->query_parameters );
}

sub prepare_headers {
    my ( $self, $c ) = @_;
    
    $c->request->headers( $c->{_ereq}->headers );
}

sub prepare_cookies {
    my ( $self, $c ) = @_;
    
    $c->request->cookies( $c->{_ereq}->cookies );
}

sub prepare_path {
    my ( $self, $c ) = @_;
    
    # XXX: proxy check
    
    # XXX: cleaner way to get the main URI object?
    $c->request->uri( $c->{_ereq}->uri->[0] );
    
    $c->request->base( $c->{_ereq}->uri->base );
}

sub prepare_read { }

sub prepare_body {
    my ( $self, $c ) = @_;
    
    if ( $c->request->content_length ) {
        $c->request->{_body} = $c->{_ereq}->http_body;
    }
    else {
        $c->request->{_body} = 0;
    }
}

sub prepare_body_parameters {
    my ( $self, $c ) = @_;
    
    return unless $c->request->{_body};
    
    $c->request->body_parameters( $c->{_ereq}->body_parameters );
}

sub prepare_parameters {
    my ( $self, $c ) = @_;

    # XXX: HTTP::Engine loads HTTP::Body object when you call this,
    # even if no Content-Length
    $c->request->parameters( $c->{_ereq}->parameters );
}

sub prepare_uploads {
    my ( $self, $c ) = @_;
    
    return unless $c->request->{_body};
    
    $c->request->uploads( $c->{_ereq}->uploads );
}

sub finalize_uploads {
    my ( $self, $c ) = @_;

    my $request = $c->request;
    foreach my $key (keys %{ $request->uploads }) {
        my $upload = $request->uploads->{$key};
        unlink grep { -e $_ } map { $_->tempname }
          (ref $upload eq 'ARRAY' ? @{$upload} : ($upload));
    }
}

sub finalize_cookies {
    my ( $self, $c ) = @_;
    
    $c->{_eres}->cookies( $c->response->cookies );
}

sub finalize_headers {
    my ( $self, $c ) = @_;
    
    $c->{_eres}->status( $c->response->status );
    $c->{_eres}->headers( $c->response->headers );
}

sub finalize_body {
    my ( $self, $c ) = @_;
    
    $c->{_eres}->body( $c->response->body );
}

sub unescape_uri {
    my ( $self, $str ) = @_;

    $str =~ s/(?:%([0-9A-Fa-f]{2})|\+)/defined $1 ? chr(hex($1)) : ' '/eg;

    return $str;
}

1;