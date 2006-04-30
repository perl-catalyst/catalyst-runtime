package Catalyst::Test;

use strict;
use warnings;

use Catalyst::Exception;
use Catalyst::Utils;
use UNIVERSAL::require;

=head1 NAME

Catalyst::Test - Test Catalyst Applications

=head1 SYNOPSIS

    # Helper
    script/test.pl

    # Tests
    use Catalyst::Test 'TestApp';
    request('index.html');
    get('index.html');

    # Run tests against a remote server
    CATALYST_SERVER='http://localhost:3000/' prove -r -l lib/ t/

    # Tests with inline apps need to use Catalyst::Engine::Test
    package TestApp;

    use Catalyst;

    sub foo : Global {
            my ( $self, $c ) = @_;
            $c->res->output('bar');
    }

    __PACKAGE__->setup();

    package main;

    use Test::More tests => 1;
    use Catalyst::Test 'TestApp';

    ok( get('/foo') =~ /bar/ );

=head1 DESCRIPTION

Test Catalyst Applications.

=head2 METHODS

=head2 get

Returns the content.

    my $content = get('foo/bar?test=1');

=head2 request

Returns a C<HTTP::Response> object.

    my $res = request('foo/bar?test=1');

=cut

sub import {
    my $self  = shift;
    my $class = shift;

    my ( $get, $request );

    if ( $ENV{CATALYST_SERVER} ) {
        $request = sub { remote_request(@_) };
        $get     = sub { remote_request(@_)->content };
    }

    else {
        unless( $class->can("can") ) {
            $class->require;
            die $@ if $@;
        }
        $class->import;

        $request = sub { local_request( $class, @_ ) };
        $get     = sub { local_request( $class, @_ )->content };
    }

    no strict 'refs';
    my $caller = caller(0);
    *{"$caller\::request"} = $request;
    *{"$caller\::get"}     = $get;
}

=head2 local_request

=cut

sub local_request {
    my $class = shift;

    require HTTP::Request::AsCGI;

    my $request = Catalyst::Utils::request( shift(@_) );
    my $cgi     = HTTP::Request::AsCGI->new( $request, %ENV )->setup;

    $class->handle_request;

    return $cgi->restore->response;
}

my $agent;

=head2 remote_request

Do an actual remote request using LWP.

=cut

sub remote_request {

    require LWP::UserAgent;

    my $request = Catalyst::Utils::request( shift(@_) );
    my $server  = URI->new( $ENV{CATALYST_SERVER} );

    if ( $server->path =~ m|^(.+)?/$| ) {
        $server->path("$1");    # need to be quoted
    }

    $request->uri->scheme( $server->scheme );
    $request->uri->host( $server->host );
    $request->uri->port( $server->port );
    $request->uri->path( $server->path . $request->uri->path );

    unless ($agent) {

        $agent = LWP::UserAgent->new(
            keep_alive   => 1,
            max_redirect => 0,
            timeout      => 60,
        );

        $agent->env_proxy;
    }

    return $agent->request($request);
}

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
