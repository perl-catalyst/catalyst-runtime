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
