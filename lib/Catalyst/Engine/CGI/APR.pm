package Catalyst::Engine::CGI::APR;

use strict;
use base 'Catalyst::Engine::CGI::Base';

use APR;
use APR::Pool;
use APR::Request;
use APR::Request::CGI;
use APR::Request::Param;

=head1 NAME

Catalyst::Engine::CGI::APR - The CGI APR Engine

=head1 SYNOPSIS

A script using the Catalyst::Engine::CGI::APR module might look like:

    #!/usr/bin/perl -w

    BEGIN { 
       $ENV{CATALYST_ENGINE} = 'CGI::APR';
    }

    use strict;
    use lib '/path/to/MyApp/lib';
    use MyApp;

    MyApp->run;

=head1 DESCRIPTION

This Catalyst engine uses C<APR::Request> for parsing of message body.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::CGI::Base>.

=over 4

=item $c->prepare_parameters

=cut

sub prepare_parameters {
    my $c = shift;

    my @params;

    $c->cgi->param->do( sub {
        my ( $field, $value ) = @_;
        push( @params, $field, $value );
        return 1;    
    });

    $c->request->param(@params);
}

=item $c->prepare_request

=cut

sub prepare_request {
    my $c = shift;
    $c->cgi( APR::Request::CGI->new( APR::Pool->new ) );
}

=item $c->prepare_uploads

=cut

sub prepare_uploads {
    my $c = shift;

    my @uploads;

    $c->cgi->upload->do( sub {
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

L<Catalyst>, L<Catalyst::Engine>, L<Catalyst::Engine::CGI::Base>, 
sL<APR::Request>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
