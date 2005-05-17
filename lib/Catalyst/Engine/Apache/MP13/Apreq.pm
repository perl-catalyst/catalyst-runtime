package Catalyst::Engine::Apache::MP13::Apreq;

use strict;
use base 'Catalyst::Engine::Apache::MP13::Base';

use Apache::Request ();

=head1 NAME

Catalyst::Engine::Apache::MP13::Apreq - Apreq class for MP 1.3 Engines

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst engine specialized for Apache mod_perl version 1.3x.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::Apache::MP13::Base>.

=over 4

=item $c->prepare_parameters

=cut

sub prepare_parameters {
    my $c = shift;

    my @params;

    $c->apache->param->do( sub {
        my ( $field, $value ) = @_;
        push( @params, $field, $value );
        return 1;
    });

    $c->request->param(@params);
}

=item $c->prepare_request($r)

=cut

sub prepare_request {
    my ( $c, $r ) = @_;
    $c->apache( Apache::Request->new($r) );
}

=item $c->prepare_uploads

=cut

sub prepare_uploads {
    my $c = shift;

    my @uploads;

    for my $upload ( $c->apache->upload ) {

        my $object = Catalyst::Request::Upload->new(
            filename => $upload->filename,
            size     => $upload->size,
            tempname => $upload->tempname,
            type     => $upload->type
        );

        push( @uploads, $upload->name, $object );
    }

    $c->request->upload(@uploads);
}

=back

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine>, L<Catalyst::Engine::Apache::MP13::Base>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
