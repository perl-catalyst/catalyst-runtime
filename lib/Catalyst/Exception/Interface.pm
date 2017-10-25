package Catalyst::Exception::Interface;

use Moose::Role;
use if !eval { require Moose; Moose->VERSION('2.1300') },
    'MooseX::Role::WithOverloading';
use namespace::clean -except => 'meta';

use overload
    q{""}    => sub { $_[0]->as_string },
    fallback => 1;

requires qw/as_string throw rethrow/;

1;

__END__

=head1 NAME

Catalyst::Exception::Interface - Role defining the interface for Catalyst exceptions

=head1 SYNOPSIS

   package My::Catalyst::Like::Exception;
   use Moose;
   use namespace::clean -except => 'meta';

   with 'Catalyst::Exception::Interface';

   # This comprises the required interface.
   sub as_string { 'the exception text for stringification' }
   sub throw { shift; die @_ }
   sub rethrow { shift; die @_ }

=head1 DESCRIPTION

This is a role for the required interface for Catalyst exceptions.

It ensures that all exceptions follow the expected interface,
and adds overloading for stringification when composed onto a
class.

Note that if you compose this role onto another role, that role
must use L<MooseX::Role::WithOverloading>.

=head1 REQUIRED METHODS

=head2 as_string

=head2 throw

=head2 rethrow

=head1 METHODS

=head2 meta

Provided by Moose

=head1 SEE ALSO

=over 4

=item L<Catalyst>

=item L<Catalyst::Exception>

=back

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
