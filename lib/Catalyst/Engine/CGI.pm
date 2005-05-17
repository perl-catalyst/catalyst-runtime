package Catalyst::Engine::CGI;

use strict;
use base 'Catalyst::Engine::CGI::Base';

use CGI;

our @compile = qw[
    delete
    http
    new_MultipartBuffer
    param
    parse_keywordlist
    read_from_client
    read_multipart
    tmpFileName
    uploadInfo
    url_param
    user_agent
];

CGI->compile(@compile);

__PACKAGE__->mk_accessors('cgi');

=head1 NAME

Catalyst::Engine::CGI - The CGI Engine

=head1 SYNOPSIS

A script using the Catalyst::Engine::CGI module might look like:

    #!/usr/bin/perl -w

    use strict;
    use lib '/path/to/MyApp/lib';
    use MyApp;

    MyApp->run;

The application module (C<MyApp>) would use C<Catalyst>, which loads the
appropriate engine module.

=head1 DESCRIPTION

This is the Catalyst engine specialized for the CGI environment (using the
C<CGI> and C<CGI::Cookie> modules).

=head1 METHODS

=over 4

=item $c->cgi

Contains the C<CGI> object.

=back

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::CGI::Base>.

=over 4

=item $c->prepare_body

=cut

sub prepare_body {
    my $c = shift;

    # XXX this is undocumented in CGI.pm. If Content-Type is not
    # application/x-www-form-urlencoded or multipart/form-data
    # CGI.pm will read STDIN into a param, POSTDATA.

    $c->request->body( $c->cgi->param('POSTDATA') );
}

=item $c->prepare_parameters

=cut

sub prepare_parameters {
    my $c = shift;

    my ( @params );

    if ( $c->request->method eq 'POST' ) {
        for my $param ( $c->cgi->url_param ) {
            for my $value (  $c->cgi->url_param($param) ) {
                push ( @params, $param, $value );
            }
        }
    }

    for my $param ( $c->cgi->param ) {
        for my $value (  $c->cgi->param($param) ) {
            push ( @params, $param, $value );
        }
    }

    $c->request->param(@params);
}

=item $c->prepare_request

=cut

sub prepare_request {
    my ( $c, $object ) = @_;

    my $cgi;

    if ( defined($object) && ref($object) ) {

        if ( $object->isa('Apache') ) {                   # MP 1.3
            $cgi = CGI->new($object);
        }

        elsif ( $object->isa('Apache::RequestRec') ) {    # MP 1.99
            $cgi = CGI->new($object);
        }

        elsif ( $object->isa('Apache2::RequestRec') ) {   # MP 2.00
            $cgi = CGI->new($object);
        }

        elsif ( $object->isa('CGI') ) {
            $cgi = $object;
        }

        else {
            my $class = ref($object);
            die( qq/Invalid argument $object/ );
        }
    }

    $c->cgi( $cgi || CGI->new );
}

=item $c->prepare_uploads

=cut

sub prepare_uploads {
    my $c = shift;

    my @uploads;

    for my $param ( $c->cgi->param ) {

        my @values = $c->cgi->param($param);

        next unless ref( $values[0] );

        for my $fh (@values) {

            next unless my $size = ( stat $fh )[7];

            my $info        = $c->cgi->uploadInfo($fh);
            my $tempname    = $c->cgi->tmpFileName($fh);
            my $type        = $info->{'Content-Type'};
            my $disposition = $info->{'Content-Disposition'};
            my $filename    = ( $disposition =~ / filename="([^;]*)"/ )[0];

            my $upload = Catalyst::Request::Upload->new(
                filename => $filename,
                size     => $size,
                tempname => $tempname,
                type     => $type
            );

            push( @uploads, $param, $upload );
        }
    }

    $c->request->upload(@uploads);
}

=back

=head1 SEE ALSO

L<Catalyst> L<Catalyst::Engine> L<Catalyst::Engine::CGI::Base>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
