package Catalyst::DispatchType::Regex;

use strict;
use base qw/Catalyst::DispatchType/;

sub prepare_action {
    my ($self, $c, $path) = @_;

    if ( my $action = $self->{paths}->{$path} ) {
        $c->req->action($path);
        $c->req->match($path);
        $c->action($action);
        $c->namespace($action->prefix);
        return 1;
    }

    foreach my $compiled (@{$self->{compiled}||[]}) {
        if ( my @snippets = ( $path =~ $compiled->{re} ) ) {
            $c->req->action($compiled->{path});
            $c->req->match($path);
            $c->req->snippets(\@snippets);
            $c->action($compiled->{action});
            $c->namespace($compiled->{action}->prefix);
            return 1;
        }
    }

    return 0;
}

sub register_action {
    my ( $self, $c, $action ) = @_;
    my $attrs = $action->attributes;
    my @register = map { @{$_ || []} } @{$attrs}{'Regex', 'Regexp'};
    foreach my $r (@register) {
        $self->{paths}{$r} = $action;
        push(@{$self->{compiled}},
            {
                re => qr#$r#,
                action => $action,
                path => $r,
            } );
    }
}

1;
