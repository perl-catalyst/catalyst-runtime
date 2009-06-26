package Catalyst::Exception;

# XXX: See bottom of file for Exception implementation

package Catalyst::Exception::Base;

use Moose;
use Carp;
use namespace::clean -except => 'meta';

=head1 NAME

Catalyst::Exception - Catalyst Exception Class

=head1 SYNOPSIS

   Catalyst::Exception->throw( qq/Fatal exception/ );

See also L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst Exception class.

=head1 METHODS

=head2 throw( $message )

=head2 throw( message => $message )

=head2 throw( error => $error )

Throws a fatal exception.

=cut

has message => (
    is  => 'ro',
    isa => 'Str',
);

use overload q{""} => \&as_string;

sub as_string {
    my ($self) = @_;
    return $self->message;
}

sub throw {
    my $class  = shift;
    my %params = @_ == 1 ? ( error => $_[0] ) : @_;

    $params{message} = $params{message} || $params{error} || $! || '';
    my $error = $class->new(%params);

    local $Carp::CarpLevel = 1;

    croak($error);
}

=head2 meta

Provided by Moose

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

Catalyst::Exception::Base->meta->make_immutable;

package Catalyst::Exception;

use Moose;
use namespace::clean -except => 'meta';

use vars qw[$CATALYST_EXCEPTION_CLASS];

BEGIN {
    extends($CATALYST_EXCEPTION_CLASS || 'Catalyst::Exception::Base');
}

__PACKAGE__->meta->make_immutable;

1;
