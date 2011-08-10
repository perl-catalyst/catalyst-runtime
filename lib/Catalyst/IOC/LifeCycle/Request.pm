package Catalyst::IOC::LifeCycle::Request;
use Moose::Role;
use namespace::autoclean;
use Carp;
with 'Bread::Board::LifeCycle';

around get => sub {
    my $orig = shift;
    my $self = shift;

    my $instance = $self->$orig(@_);

    my $ctx = $self->param('ctx')
        or confess qq/This component has a Request lifecycle.\n/ .
                   qq/The 'ctx' parameter is mandatory./;

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
