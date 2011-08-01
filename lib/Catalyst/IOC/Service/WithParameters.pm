package Catalyst::IOC::Service::WithParameters;
use Moose::Role;

with 'Bread::Board::Service',
     'Bread::Board::Service::WithParameters';

sub _build_parameters {
    return {
        accept_context_args => {
            isa      => 'ArrayRef|Undef',
            required => 0,
            default  => undef,
        }
    };
}

no Moose::Role;
1;

__END__

=pod

=head1 NAME

Catalyst::IOC::Service::WithParameters

=head1 DESCRIPTION

=head1 METHODS

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
