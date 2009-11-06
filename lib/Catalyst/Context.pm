package Catalyst::Context;

use Moose;

BEGIN { require 5.008004; }

has action => (is => 'rw');
has counter => (is => 'rw', default => sub { {} });
has namespace => (is => 'rw');
has request_class => (is => 'ro', default => 'Catalyst::Request');
has request => (is => 'rw', default => sub { $_[0]->request_class->new({}) }, required => 1, lazy => 1);
has response_class => (is => 'ro', default => 'Catalyst::Response');
has response => (is => 'rw', default => sub { $_[0]->response_class->new({}) }, required => 1, lazy => 1);
has stack => (is => 'ro', default => sub { [] });
has stash => (is => 'rw', default => sub { {} });
has state => (is => 'rw', default => 0);
has stats => (is => 'rw');

# Remember to update this in Catalyst::Runtime as well!

our $VERSION = '5.80013';

{
    my $dev_version = $VERSION =~ /_\d{2}$/;
    *_IS_DEVELOPMENT_VERSION = sub () { $dev_version };
}

$VERSION = eval $VERSION;

no Moose;

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Catalyst::Context - object for keeping request related state

=head1 ATTRIBUTES 

=head3 action

=head3 counter

=head3 namespace

=head3 request_class

=head3 request

=head3 response_class

=head3 response

=head3 stack

=head3 stash

=head3 state

=head3 stats

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Model>, L<Catalyst::View>, L<Catalyst::Controller>.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

