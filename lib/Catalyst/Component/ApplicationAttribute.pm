package Catalyst::Component::ApplicationAttribute;

use Moose::Role;
use namespace::clean -except => 'meta';

# Future - isa => 'ClassName|Catalyst' performance?
#           required => 1 breaks tests..
has _application => (is => 'ro', weak_ref => 1);
sub _app { (shift)->_application(@_) }

override BUILDARGS => sub {
    my ($self, $app) = @_;

    my $args = super();
    $args->{_application} = $app;

    return $args;
};

1;

__END__

=head1 NAME

Catalyst::Component::ApplicationAttribute - Moose Role for components which capture the application context.

=head1 SYNOPSIS

    package My::Component;
    use Moose;
    extends 'Catalyst::Component';
    with 'Catalyst::Component::ApplicationAttribute';

    # Your code here

    1;

=head1 DESCRIPTION

This role provides a BUILDARGS method which captures the application context into an attribute.

=head1 ATTRIBUTES

=head2 _application

Weak reference to the application context.

=head1 METHODS

=head2 BUILDARGS ($self, $app)

BUILDARGS method captures the application context into the C<_application> attribute.

=head2 _application

Reader method for the application context.

=head1 SEE ALSO

L<Catalyst::Component>,
L<Catalyst::Controller>.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
