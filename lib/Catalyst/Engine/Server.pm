package Catalyst::Engine::Server;

use strict;
use base 'Catalyst::Engine::CGI';

=head1 NAME

Catalyst::Engine::Server - Catalyst Server Engine

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst engine specialized for development and testing.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::CGI>.

=over 4

=item $c->run

=cut

sub run {
    my $class = shift;
    my $port  = shift || 3000;

    my $server = Catalyst::Engine::Server::Simple->new($port);

    $server->handler( sub { $class->handler } );
    $server->run;
}

=back

=head1 SEE ALSO

L<Catalyst>, L<HTTP::Server::Simple>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

package Catalyst::Engine::Server::Simple;

use strict;
use base 'HTTP::Server::Simple';

my %CLEAN_ENV = %ENV;

sub handler {
    my $self = shift;

    if (@_) {
        $self->{handler} = shift;
    }

    else {
        $self->{handler}->();
    }
}

sub print_banner {
    my $self = shift;

    printf(
        "You can connect to your server at http://%s:%d/\n",
        $self->host || 'localhost',
        $self->port
    );
}

sub accept_hook {
    %ENV = ( %CLEAN_ENV, SERVER_SOFTWARE => "Catalyst/$Catalyst::VERSION" );
}

our %env_mapping = (
    protocol     => "SERVER_PROTOCOL",
    localport    => "SERVER_PORT",
    localname    => "SERVER_NAME",
    path         => "PATH_INFO",
    request_uri  => "REQUEST_URI",
    method       => "REQUEST_METHOD",
    peeraddr     => "REMOTE_ADDR",
    peername     => "REMOTE_HOST",
    query_string => "QUERY_STRING",
);

sub setup {
    no warnings 'uninitialized';
    my $self = shift;

    while ( my ( $item, $value ) = splice @_, 0, 2 ) {
        if ( $self->can($item) ) {
            $self->$item($value);
        }
        elsif ( my $k = $env_mapping{$item} ) {
            $ENV{$k} = $value;
        }
    }
}

sub headers {
    my $self    = shift;
    my $headers = shift;

    while ( my ( $tag, $value ) = splice @{$headers}, 0, 2 ) {
        $tag = uc($tag);
        $tag =~ s/^COOKIES$/COOKIE/;
        $tag =~ s/-/_/g;
        $tag = "HTTP_" . $tag
          unless $tag =~ m/^CONTENT_(?:LENGTH|TYPE)$/;

        if ( exists $ENV{$tag} ) {
            $ENV{$tag} .= "; $value";
        }
        else {
            $ENV{$tag} = $value;
        }
    }
}

1;
