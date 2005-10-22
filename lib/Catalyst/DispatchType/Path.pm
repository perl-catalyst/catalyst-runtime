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
        unless ($r =~ m!^/!) {    # It's a relative path
            $r = $action->prefix."/$r";
        }
        push(@register, $r);
    }

    if ($attrs->{Global} || $attrs->{Absolute}) {
        push(@register, $action->name); # Register sub name against root
    }

    if ($attrs->{Local} || $attrs->{Relative}) {
        push(@register, join('/', $action->prefix, $action->name));
            # Register sub name as a relative path
    }

    foreach my $r (@register) {
        $r =~ s!^/!!;
        $self->{paths}{$r} = $action;
    }
}

1;
