package Catalyst::Plugin::Test::Headers;

use strict;

sub prepare {
    my $class = shift;

    my $c = $class->NEXT::prepare(@_);

    $c->response->header( 'X-Catalyst-Engine' => $c->engine );
    $c->response->header( 'X-Catalyst-Debug' => $c->debug ? 1 : 0 );
    
    {
        my $components = join( ', ', sort keys %{ $c->components } );
        $c->response->header( 'X-Catalyst-Components' => $components );
    }

    {
        no strict 'refs';
        my $plugins = join( ', ', sort grep { m/^Catalyst::Plugin/ } @{ $class . '::ISA' } );
        $c->response->header( 'X-Catalyst-Plugins' => $plugins );
    }

    return $c;
}

sub prepare_action {
    my $c = shift;
    $c->NEXT::prepare_action(@_);
    $c->res->header( 'X-Catalyst-Action' => $c->req->action );
}

1;
