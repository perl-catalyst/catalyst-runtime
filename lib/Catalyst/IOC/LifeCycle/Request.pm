package Catalyst::IOC::LifeCycle::Request;
use Moose::Role;
use namespace::autoclean;
with 'Bread::Board::LifeCycle';

around get => sub {
    my $orig = shift;
    my $self = shift;

    my $instance = $self->$orig(@_);

# FIXME -
# during setup in Catalyst.pm:
#  - $class->setup_actions (line 3025)
#      - $c->dispatcher->setup_actions (line 2271)
#          - $c->components in Catalyst/Dispatcher.pm line 604
# which boils down to line 616 in Catalyst/IOC/Container.pm
# resolving the component _without_ the 'context' parameter.
# Should it get the context parameter? Should all calls to a
# ConstructorInjection service pass that parameter?
    my $ctx = $self->param('ctx')
        or return $instance;

    my $stash_key = "__Catalyst_IOC_LifeCycle_Request_" . $self->name;
    return $ctx->stash->{$stash_key} ||= $instance;
};

1;

__END__

=pod

=head1 NAME

Catalyst::IOC::LifeCycle::Request - Components that last for one request

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
