package Catalyst::Test;

use strict;
use UNIVERSAL::require;

$ENV{CATALYST_ENGINE} = 'Test';

=head1 NAME

Catalyst::Test - Test Catalyst applications

=head1 SYNOPSIS

    # Helper
    script/test.pl

    # Tests
    use Catalyst::Test 'TestApp';
    request('index.html');
    get('index.html');

    # Run tests against a remote server
    CATALYST_SERVER='http://localhost:3000/' prove -l lib/ t/

    # Tests with inline apps need to use Catalyst::Engine::Test
    package TestApp;

    use Catalyst qw[-Engine=Test];

    __PACKAGE__->action(
        foo => sub {
            my ( $self, $c ) = @_;
            $c->res->output('bar');
        }
    );

    package main;

    use Test::More tests => 1;
    use Catalyst::Test 'TestApp';

    ok( get('/foo') =~ /bar/ );

=head1 DESCRIPTION

Test Catalyst applications.

=head2 METHODS

=over 4

=item get

Returns the content.

    my $content = get('foo/bar?test=1');

=item request

Returns a C<HTTP::Response> object.

    my $res =request('foo/bar?test=1');

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
        $class->require;
        my $error = $UNIVERSAL::require::ERROR;
        die qq/Couldn't load "$class", "$error"/ if $@;

        $class->import;

        $request = sub { $class->run(@_) };
        $get     = sub { $class->run(@_)->content };
    }

    no strict 'refs';
    my $caller = caller(0);
    *{"$caller\::request"} = $request;
    *{"$caller\::get"}     = $get;
}

my $agent;

=item remote_request

Do an actual remote rquest using LWP.

=cut

sub remote_request {
    my $request = shift;

    require LWP::UserAgent;

    unless ( ref $request ) {

        my $uri =
          ( $request =~ m/http/i )
          ? URI->new($request)
          : URI->new( 'http://localhost' . $request );

        $request = $uri->canonical;
    }

    unless ( ref $request eq 'HTTP::Request' ) {
        $request = HTTP::Request->new( 'GET', $request );
    }

    my $server = URI->new( $ENV{CATALYST_SERVER} );

    if ( $server->path =~ m|^(.+)?/$| ) {
        $server->path("$1");    # need to be quoted
    }

    $request->uri->scheme( $server->scheme );
    $request->uri->host( $server->host );
    $request->uri->port( $server->port );
    $request->uri->path( $server->path . $request->uri->path );

    unless ($agent) {
        $agent = LWP::UserAgent->new(

            #  cookie_jar   => {},
            keep_alive   => 1,
            max_redirect => 0,
            timeout      => 60,
        );
        $agent->env_proxy;
    }

    return $agent->request($request);
}

=back 

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
