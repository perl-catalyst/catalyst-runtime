package Catalyst::Exception::Basic;

use MooseX::Role::WithOverloading;
use Carp;
use namespace::clean -except => 'meta';

with 'Catalyst::Exception::Interface';

has message => (
    is      => 'ro',
    isa     => 'Str',
    default => sub { $! || '' },
);

sub as_string {
    my ($self) = @_;
    return $self->message;
}

around BUILDARGS => sub {
    my ($next, $class, @args) = @_;
    if (@args == 1 && !ref $args[0]) {
        @args = (message => $args[0]);
    }

    my $args = $class->$next(@args);
    $args->{message} ||= $args->{error}
        if exists $args->{error};

    return $args;
};

sub throw {
    my $class = shift;
    my $error = $class->new(@_);
    local $Carp::CarpLevel = 1;
    croak $error;
}

sub rethrow {
    my ($self) = @_;
    croak $self;
}

1;

=head1 NAME

Catalyst::Exception::Basic - Basic Catalyst Exception Role

=head1 SYNOPSIS

   package My::Exception;
   use Moose;
   use namespace::clean -except => 'meta';

   with 'Catalyst::Exception::Basic';

   # Elsewhere..
   My::Exception->throw( qq/Fatal exception/ );

See also L<Catalyst> and L<Catalyst::Exception>.

=head1 DESCRIPTION

This is the basic Catalyst Exception role which implements all of
L<Catalyst::Exception::Interface>.

=head1 ATTRIBUTES

=head2 message

Holds the exception message.

=head1 METHODS

=head2 as_string

Stringifies the exception's message attribute.
Called when the object is stringified by overloading.

=head2 throw( $message )

=head2 throw( message => $message )

=head2 throw( error => $error )

Throws a fatal exception.

=head2 rethrow( $exception )

Rethrows a caught exception.

=head2 meta

Provided by Moose

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
