package Catalyst::Base;
use Moose;
BEGIN { extends 'Catalyst::Controller' }

after 'BUILD' => sub {
    my $self = shift;
    warn(ref($self) . " is using the deprecated Catalyst::Base, update your application as this will be removed in the next major release");
};

no Moose;

1;

__END__

=head1 NAME

Catalyst::Base - Deprecated base class

=head1 DESCRIPTION

This used to be the base class for Catalyst Controllers. It
remains here for compatibility reasons, but its use is highly deprecated.

If your application produces a warning, then please update your application to
inherit from L<Catalyst::Controller> instead.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Controller>.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
