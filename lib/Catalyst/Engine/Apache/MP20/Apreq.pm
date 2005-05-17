package Catalyst::Engine::Apache::MP20::Apreq;

use strict;
use base 'Catalyst::Engine::Apache::MP20::Base';

use Apache2::Request ();
use Apache2::Upload  ();

=head1 NAME

Catalyst::Engine::Apache::MP20::Apreq - Apreq class for MP 2.0 Engines

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst engine specialized for Apache mod_perl version 2.0.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::Apache::MP20::Base>.

=over 4

=item $c->prepare_parameters

=cut

sub prepare_parameters {
    my $c = shift;

    my @params;

    if ( my $table = $c->apache->param ) {

        $table->do( sub {
            my ( $field, $value ) = @_;
            push( @params, $field, $value );
            return 1;
        });

        $c->request->param(@params);
    }
}

=item $c->prepare_request($r)

=cut

sub prepare_request {
    my ( $c, $r ) = @_;
    $c->apache( Apache2::Request->new($r) );
}

=item $c->prepare_uploads

=cut

sub prepare_uploads {
    my $c = shift;

    my @uploads;

    $c->apache->upload->do( sub {
        my ( $field, $upload ) = @_;

        my $object = Catalyst::Request::Upload->new(
            filename => $upload->filename,
            size     => $upload->size,
            tempname => $upload->tempname,
            type     => $upload->type
        );

        push( @uploads, $field, $object );

        return 1;
    });

    $c->request->upload(@uploads);
}

=back

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine>, L<Catalyst::Engine::Apache::MP20::Base>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
