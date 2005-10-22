package Catalyst::DispatchType::Path;

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

    return 0;
}

sub register_action {
    my ( $self, $c, $action ) = @_;
    my $attrs = $action->attributes;
    my @register;
    foreach my $r (@{$attrs->{Path} || []}) {
        unless ($r =~ m!^/!) {
            $r = $action->prefix."/$r";
        }
        push(@register, $r);
    }

    if ($attrs->{Global} || $attrs->{Absolute}) {
        push(@register, $action->name);
    }

    if ($attrs->{Local} || $attrs->{Relative}) {
        push(@register, join('/', $action->prefix, $action->name));
    }

    foreach my $r (@register) {
        $r =~ s!^/!!;
        $self->{paths}{$r} = $action;
    }
}

1;
