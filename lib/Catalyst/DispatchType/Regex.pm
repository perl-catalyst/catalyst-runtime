package Catalyst::DispatchType::Regex;

use strict;
use base qw/Catalyst::DispatchType::Path/;

sub prepare_action {
    my ($self, $c, $path) = @_;

    return if $self->SUPER::prepare_action($c, $path);
        # Check path against plain text first

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
        $self->{paths}{$r} = $action; # Register path for superclass
        push(@{$self->{compiled}},    # and compiled regex for us
            {
                re => qr#$r#,
                action => $action,
                path => $r,
            } );
    }
}

1;
