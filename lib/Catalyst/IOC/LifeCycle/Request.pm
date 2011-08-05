package Catalyst::IOC::LifeCycle::Request;
use Moose::Role;
use namespace::autoclean;

# based on Bread::Board::LifeCycle::Request from OX
# just behaves like a singleton - ::Request instances
# will get flushed after the response is sent
with 'Bread::Board::LifeCycle::Singleton';

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
