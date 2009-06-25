package Catalyst::Test;

use strict;
use warnings;
use Test::More ();

use Catalyst::Exception;
use Catalyst::Utils;
use Class::MOP;
use Sub::Exporter;

my $build_exports = sub {
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

    my $ctx_request = sub {
        my $me      = ref $self || $self;

        ### throw an exception if ctx_request is being used against a remote
        ### server
        Catalyst::Exception->throw("$me only works with local requests, not remote")
            if $ENV{CATALYST_SERVER};

        ### check explicitly for the class here, or the Cat->meta call will blow
        ### up in our face
        Catalyst::Exception->throw("Must specify a test app: use Catalyst::Test 'TestApp'") unless $class;

        ### place holder for $c after the request finishes; reset every time
        ### requests are done.
        my $c;

        ### hook into 'dispatch' -- the function gets called after all plugins
        ### have done their work, and it's an easy place to capture $c.

        my $meta = Catalyst->meta;
        $meta->make_mutable;
        $meta->add_after_method_modifier( "dispatch", sub {
            $c = shift;
        });
        $meta->make_immutable;

        ### do the request; C::T::request will know about the class name, and
        ### we've already stopped it from doing remote requests above.
        my $res = $request->( @_ );

        ### return both values
        return ( $res, $c );
    };

    return {
        request      => $request,
        get          => $get,
        ctx_request  => $ctx_request,
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
};

our $default_host;

{
    my $import = Sub::Exporter::build_exporter({
        groups => [ all => $build_exports ],
        into_level => 1,
    });


    sub import {
        my ($self, $class, $opts) = @_;
        $import->($self, '-all' => { class => $class });
        $opts = {} unless ref $opts eq 'HASH';
        $default_host = $opts->{default_host} if exists $opts->{default_host};
        return 1;
    }
}

=head1 NAME

Catalyst::Test - Test Catalyst Applications

=head1 SYNOPSIS

    # Helper
    script/test.pl

    # Tests
    use Catalyst::Test 'TestApp';
    my $content  = get('index.html');           # Content as string
    my $response = request('index.html');       # HTTP::Response object
    my($res, $c) = ctx_request('index.html');      # HTTP::Response & context object

    use HTTP::Request::Common;
    my $response = request POST '/foo', [
        bar => 'baz',
        something => 'else'
    ];

    # Run tests against a remote server
    CATALYST_SERVER='http://localhost:3000/' prove -r -l lib/ t/

    use Catalyst::Test 'TestApp';
    use Test::More tests => 1;

    ok( get('/foo') =~ /bar/ );

    # mock virtual hosts
    use Catalyst::Test 'MyApp', { default_host => 'myapp.com' };
    like( get('/whichhost'), qr/served by myapp.com/ );
    like( get( '/whichhost', { host => 'yourapp.com' } ), qr/served by yourapp.com/ );
    {
        local $Catalyst::Test::default_host = 'otherapp.com';
        like( get('/whichhost'), qr/served by otherapp.com/ );
    }

=head1 DESCRIPTION

This module allows you to make requests to a Catalyst application either without
a server, by simulating the environment of an HTTP request using
L<HTTP::Request::AsCGI> or remotely if you define the CATALYST_SERVER
environment variable. This module also adds a few Catalyst-specific
testing methods as displayed in the method section.

The L<get> and L<request> functions take either a URI or an L<HTTP::Request>
object.

=head1 INLINE TESTS WILL NO LONGER WORK

While it used to be possible to inline a whole testapp into a C<.t> file for a
distribution, this will no longer work.

The convention is to place your L<Catalyst> test apps into C<t/lib> in your
distribution. E.g.: C<t/lib/TestApp.pm>, C<t/lib/TestApp/Controller/Root.pm>,
etc..  Multiple test apps can be used in this way.

Then write your C<.t> files like so:

    use strict;
    use warnings;
    use FindBin '$Bin';
    use lib "$Bin/lib";
    use Test::More tests => 6;
    use Catalyst::Test 'TestApp';

=head1 METHODS

=head2 $content = get( ... )

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

=head2 $res = request( ... );

Returns an L<HTTP::Response> object. Accepts an optional hashref for request
header configuration; currently only supports setting 'host' value.

    my $res = request('foo/bar?test=1');
    my $virtual_res = request('foo/bar?test=1', {host => 'virtualhost.com'});

=head1 FUNCTIONS

=head2 ($res, $c) = ctx_request( ... );

Works exactly like L<request>, except it also returns the Catalyst context object,
C<$c>. Note that this only works for local requests.

=head2 $res = Catalyst::Test::local_request( $AppClass, $url );

Simulate a request using L<HTTP::Request::AsCGI>.

=cut

sub local_request {
    my $class = shift;

    require HTTP::Request::AsCGI;

    my $request = Catalyst::Utils::request( shift(@_) );
    _customize_request($request, @_);
    my $cgi     = HTTP::Request::AsCGI->new( $request, %ENV )->setup;

    $class->handle_request( env => \%ENV );

    return $cgi->restore->response;
}

my $agent;

=head2 $res = Catalyst::Test::remote_request( $url );

Do an actual remote request using LWP.

=cut

sub remote_request {

    require LWP::UserAgent;

    my $request = Catalyst::Utils::request( shift(@_) );
    my $server  = URI->new( $ENV{CATALYST_SERVER} );

    _customize_request($request, @_);

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

            # work around newer LWP max_redirect 0 bug
            # http://rt.cpan.org/Ticket/Display.html?id=40260
            requests_redirectable => [],
        );

        $agent->env_proxy;
    }

    return $agent->request($request);
}

sub _customize_request {
    my $request = shift;
    my $opts = pop(@_) || {};
    $opts = {} unless ref($opts) eq 'HASH';
    if ( my $host = exists $opts->{host} ? $opts->{host} : $default_host  ) {
        $request->header( 'Host' => $host );
    }
}

=head2 action_ok

Fetches the given URL and checks that the request was successful.

=head2 action_redirect

Fetches the given URL and checks that the request was a redirect.

=head2 action_notfound

Fetches the given URL and checks that the request was not found.

=head2 content_like( $url, $regexp [, $test_name] )

Fetches the given URL and returns whether the content matches the regexp.

=head2 contenttype_is

Check for given MIME type.

=head1 SEE ALSO

L<Catalyst>, L<Test::WWW::Mechanize::Catalyst>,
L<Test::WWW::Selenium::Catalyst>, L<Test::More>, L<HTTP::Request::Common>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
