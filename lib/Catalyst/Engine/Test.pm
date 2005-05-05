package Catalyst::Engine::Test;

use strict;
use base 'Catalyst::Engine::HTTP::Base';

use Catalyst::Utils;

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

This class overloads some methods from C<Catalyst::Engine::HTTP::Base>.

=over 4

=item $c->run

=cut

sub run {
    my ( $class, $request ) = @_;
    
    $request = Catalyst::Utils::request($request);

    $request->header( 
        'Host' => sprintf( '%s:%d', $request->uri->host, $request->uri->port )
    );

    my $http = Catalyst::Engine::HTTP::Base::struct->new(
        address  => '127.0.0.1',
        hostname => 'localhost',
        request  => $request,
        response => HTTP::Response->new
    );

    $http->response->date(time);

    $class->handler($http);

    return $http->response;
}

=back

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
