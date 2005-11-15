package Catalyst::Engine::Test;

use strict;
use base 'Catalyst::Engine::CGI';
use Catalyst::Utils;
use HTTP::Headers;
use HTTP::Response;
use HTTP::Status;
use NEXT;

=head1 NAME

Catalyst::Engine::Test - Catalyst Test Engine

=head1 SYNOPSIS

A script using the Catalyst::Engine::Test module might look like:

    #!/usr/bin/perl -w

    BEGIN { 
       $ENV{CATALYST_ENGINE} = 'Test';
    }

    use strict;
    use lib '/path/to/MyApp/lib';
    use MyApp;

    MyApp->run('/a/path');

=head1 DESCRIPTION

This is the Catalyst engine specialized for testing.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::CGI>.

=over 4

=item finalize_headers

=cut

sub finalize_headers {
    my ( $self, $c ) = @_;
    my $protocol = $c->request->protocol;
    my $status   = $c->response->status;
    my $message  = status_message($status);
    print "$protocol $status $message\n";
    $c->response->headers->date(time);
    $self->NEXT::finalize_headers($c);
}

=item $self->run($c)

=cut

sub run {
    my ( $self, $class, $request ) = @_;

    $request = Catalyst::Utils::request($request);

    $request->header(
        'Host' => sprintf( '%s:%d', $request->uri->host, $request->uri->port )
    );

    # We emulate CGI
    local %ENV = (
        PATH_INFO    => $request->uri->path  || '',
        QUERY_STRING => $request->uri->query || '',
        REMOTE_ADDR  => '127.0.0.1',
        REMOTE_HOST  => 'localhost',
        REQUEST_METHOD  => $request->method,
        SERVER_NAME     => 'localhost',
        SERVER_PORT     => $request->uri->port,
        SERVER_PROTOCOL => 'HTTP/1.1',
        %ENV,
    );

    # Headers
    for my $header ( $request->header_field_names ) {
        my $name = uc $header;
        $name = 'COOKIE' if $name eq 'COOKIES';
        $name =~ tr/-/_/;
        $name = 'HTTP_' . $name
          unless $name =~ m/\A(?:CONTENT_(?:LENGTH|TYPE)|COOKIE)\z/;
        my $value = $request->header($header);
        if ( exists $ENV{$name} ) {
            $ENV{$name} .= "; $value";
        }
        else {
            $ENV{$name} = $value;
        }
    }

    # STDIN
    local *STDIN;
    my $input = $request->content;
    open STDIN, '<', \$input;

    # STDOUT
    local *STDOUT;
    my $output = '';
    open STDOUT, '>', \$output;

    # Process
    $class->handle_request;

    # Response
    return HTTP::Response->parse($output);
}

=item $self->read_chunk($c, $buffer, $length)

=cut

sub read_chunk { shift; shift; *STDIN->read(@_); }

=back

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHORS

Sebastian Riedel, <sri@cpan.org>

Christian Hansen, <ch@ngmedia.com>

Andy Grundman, <andy@hybridized.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
