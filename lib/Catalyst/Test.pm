package Catalyst::Test;

use Test::More;

use Catalyst::Exception;
use Catalyst::Utils;
use Class::MOP;
use Sub::Exporter;

sub build_exports {
    my ($self, $meth, $args, $defaults) = @_;

    my $request;
    my $class = $args->{class};

    if ( $ENV{CATALYST_SERVER} ) {
        $request = sub { remote_request(@_) };
    } elsif (! $class) {
        $request = sub { Catalyst::Exception->throw("Must specify a test app: use Catalyst::Test 'TestApp'") };
    } else {
        unless (Class::MOP::is_class_loaded($class)) {
            Class::MOP::load_class($class);
        }
        $class->import;

        $request = sub { local_request( $class, @_ ) };
    }

    my $get = sub { $request->(@_)->content };

    return {
        request => $request,
        get     => $get,
        content_like => sub {
            my $action = shift;
            return Test::More->builder->like($get->($action),@_);
        },
        action_ok => sub {
            my $action = shift;
            return Test::More->builder->ok($request->($action)->is_success, @_);
        },
        action_redirect => sub {
            my $action = shift;
            return Test::More->builder->ok($request->($action)->is_redirect,@_);
        },
        action_notfound => sub {
            my $action = shift;
            return Test::More->builder->is_eq($request->($action)->code,404,@_);
        },
        contenttype_is => sub {
            my $action = shift;
            my $res = $request->($action);
            return Test::More->builder->is_eq(scalar($res->content_type),@_);
        },
    };
}

use namespace::clean;

{
    my $import = Sub::Exporter::build_exporter({
        groups => [ all => \&build_exports ],
        into_level => 1,
    });

    sub import {
        my ($self, $class) = @_;
        $import->($self, '-all' => { class => $class });
    }
}

=head1 NAME

Catalyst::Test - Test Catalyst Applications

=head1 SYNOPSIS

    # Helper
    script/test.pl

    # Tests
    use Catalyst::Test 'TestApp';
    request('index.html');
    get('index.html');

    use HTTP::Request::Common;
    my $response = request POST '/foo', [
        bar => 'baz',
        something => 'else'
    ];

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

    use Catalyst::Test 'TestApp';
    use Test::More tests => 1;

    ok( get('/foo') =~ /bar/ );

=head1 DESCRIPTION

This module allows you to make requests to a Catalyst application either without
a server, by simulating the environment of an HTTP request using
L<HTTP::Request::AsCGI> or remotely if you define the CATALYST_SERVER
environment variable. This module also adds a few catalyst
specific testing methods as displayed in the method section.

The </get> and </request> functions take either a URI or an L<HTTP::Request>
object.

=head2 METHODS

=head2 get

Returns the content.

    my $content = get('foo/bar?test=1');

Note that this method doesn't follow redirects, so to test for a
correctly redirecting page you'll need to use a combination of this
method and the L<request> method below:

    my $res = request('/'); # redirects to /y
    warn $res->header('location');
    use URI;
    my $uri = URI->new($res->header('location'));
    is ( $uri->path , '/y');
    my $content = get($uri->path);

=head2 request

Returns a C<HTTP::Response> object.

    my $res = request('foo/bar?test=1');

=head2 local_request

Simulate a request using L<HTTP::Request::AsCGI>.

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
        my $path = $1;
        $server->path("$path") if $path;    # need to be quoted
    }

    # the request path needs to be sanitised if $server is using a
    # non-root path due to potential overlap between request path and
    # response path.
    if ($server->path) {
        # If request path is '/', we have to add a trailing slash to the
        # final request URI
        my $add_trailing = $request->uri->path eq '/';
        
        my @sp = split '/', $server->path;
        my @rp = split '/', $request->uri->path;
        shift @sp;shift @rp; # leading /
        if (@rp) {
            foreach my $sp (@sp) {
                $sp eq $rp[0] ? shift @rp : last
            }
        }
        $request->uri->path(join '/', @rp);
        
        if ( $add_trailing ) {
            $request->uri->path( $request->uri->path . '/' );
        }
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

=head2 action_ok

Fetches the given url and check that the request was successful

=head2 action_redirect

Fetches the given url and check that the request was a redirect

=head2 action_notfound

Fetches the given url and check that the request was not found

=head2 content_like

Fetches the given url and matches the content against it.

=head2 contenttype_is 
    
Check for given mime type

=head1 SEE ALSO

L<Catalyst>, L<Test::WWW::Mechanize::Catalyst>,
L<Test::WWW::Selenium::Catalyst>, L<Test::More>, L<HTTP::Request::Common>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
