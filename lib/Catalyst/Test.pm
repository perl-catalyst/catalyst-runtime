package Catalyst::Test;

use strict;
use warnings;
use Test::More ();

use Plack::Test;
use Catalyst::Exception;
use Catalyst::Utils;
use Class::MOP;
use Sub::Exporter;
use Carp 'croak', 'carp';

sub _build_request_export {
    my ($self, $args) = @_;

    return sub { _remote_request(@_) }
        if $args->{remote};

    my $class = $args->{class};

    # Here we should be failing right away, but for some stupid backcompat thing
    # I don't quite remember we fail lazily here. Needs a proper deprecation and
    # then removal.
    return sub { croak "Must specify a test app: use Catalyst::Test 'TestApp'" }
        unless $class;

    Class::MOP::load_class($class) unless Class::MOP::is_class_loaded($class);
    $class->import;

    return sub { _local_request( $class, @_ ) };
}

sub _build_get_export {
    my ($self, $args) = @_;
    my $request = $args->{request};

    return sub { $request->(@_)->content };
}
sub _build_ctx_request_export {
    my ($self, $args) = @_;
    my ($class, $request) = @{ $args }{qw(class request)};

    return sub {
        my $me = ref $self || $self;

        # fail if ctx_request is being used against a remote server
        Catalyst::Exception->throw("$me only works with local requests, not remote")
            if $ENV{CATALYST_SERVER};

        # check explicitly for the class here, or the Cat->meta call will blow
        # up in our face
        Catalyst::Exception->throw("Must specify a test app: use Catalyst::Test 'TestApp'") unless $class;

        # place holder for $c after the request finishes; reset every time
        # requests are done.
        my $ctx_closed_over;

        # hook into 'dispatch' -- the function gets called after all plugins
        # have done their work, and it's an easy place to capture $c.
        my $meta = Class::MOP::get_metaclass_by_name($class);
        $meta->make_mutable;
        $meta->add_after_method_modifier( "dispatch", sub {
            $ctx_closed_over = shift;
        });
        $meta->make_immutable( replace_constructor => 1 );
        Class::C3::reinitialize(); # Fixes RT#46459, I've failed to write a test for how/why, but it does.

        # do the request; C::T::request will know about the class name, and
        # we've already stopped it from doing remote requests above.
        my $res = $args->{request}->( @_ );

        # Make sure not to leave a reference $ctx hanging around.
        # This means that the context will go out of scope as soon as the
        # caller disposes of it, rather than waiting till the next time
        # that ctx_request is called. This can be important if your $ctx
        # ends up with a reference to a shared resource or lock (for example)
        # which you want to clean up in test teardown - if the $ctx is still
        # closed over then you're stuffed...
        my $ctx = $ctx_closed_over;
        undef $ctx_closed_over;

        return ( $res, $ctx );
    };
}

my $build_exports = sub {
    my ($self, $meth, $args, $defaults) = @_;
    my $class = $args->{class};

    my $request = $self->_build_request_export({
        class  => $class,
        remote => $ENV{CATALYST_SERVER},
    });

    my $get = $self->_build_get_export({ request => $request });

    my $ctx_request = $self->_build_ctx_request_export({
        class   => $class,
        request => $request,
    });

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
            my $meth = $request->($action)->request->method;
            my @args = @_ ? @_ : ("$meth $action returns successfully");
            return Test::More->builder->ok($request->($action)->is_success,@args);
        },
        action_redirect => sub {
            my $action = shift;
            my $meth = $request->($action)->request->method;
            my @args = @_ ? @_ : ("$meth $action returns a redirect");
            return Test::More->builder->ok($request->($action)->is_redirect,@args);
        },
        action_notfound => sub {
            my $action = shift;
            my $meth = $request->($action)->request->method;
            my @args = @_ ? @_ : ("$meth $action returns a 404");
            return Test::More->builder->is_eq($request->($action)->code,404,@args);
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
        Carp::carp(
qq{Importing Catalyst::Test without an application name is deprecated:\n
Instead of saying: use Catalyst::Test;
say: use Catalyst::Test (); # If you don't want to import a test app right now.
or say: use Catalyst::Test 'MyApp'; # If you do want to import a test app.\n\n})
        unless $class;
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

The L<get|/"$content = get( ... )"> and L<request|/"$res = request( ... );">
functions take either a URI or an L<HTTP::Request> object.

=head1 INLINE TESTS WILL NO LONGER WORK

While it used to be possible to inline a whole test app into a C<.t> file for
a distribution, this will no longer work.

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
method and the L<request|/"$res = request( ... );"> method below:

    my $res = request('/'); # redirects to /y
    warn $res->header('location');
    use URI;
    my $uri = URI->new($res->header('location'));
    is ( $uri->path , '/y');
    my $content = get($uri->path);

Note also that the content is returned as raw bytes, without any attempt
to decode it into characters.

=head2 $res = request( ... );

Returns an L<HTTP::Response> object. Accepts an optional hashref for request
header configuration; currently only supports setting 'host' value.

    my $res = request('foo/bar?test=1');
    my $virtual_res = request('foo/bar?test=1', {host => 'virtualhost.com'});

=head2 ($res, $c) = ctx_request( ... );

Works exactly like L<request|/"$res = request( ... );">, except it also returns the Catalyst context object,
C<$c>. Note that this only works for local requests.

=cut

sub _request {
    my $args = shift;

    my $request = Catalyst::Utils::request(shift);

    my %extra_env;
    _customize_request($request, \%extra_env, @_);
    $args->{mangle_request}->($request) if $args->{mangle_request};

    my $ret;
    test_psgi
        %{ $args },
        app    => sub { $args->{app}->({ %{ $_[0] }, %extra_env }) },
        client => sub {
            my ($psgi_app) = @_;
            my $resp = $psgi_app->($request);
            $args->{mangle_response}->($resp) if $args->{mangle_response};
            $ret = $resp;
        };

    return $ret;
}

sub _local_request {
    my $class = shift;

    return _request({
        app => ref($class) eq "CODE" ? $class : $class->_finalized_psgi_app,
        mangle_response => sub {
            my ($resp) = @_;

            # HTML head parsing based on LWP::UserAgent
            #
            # This is because if you make a remote request with LWP, then the
            # <BASE HREF="..."> from the returned HTML document will be used
            # to fill in $res->base, as documented in HTTP::Response. We need
            # to support this in local test requests so that they work 'the same'.
            #
            # This is not just horrible and possibly broken, but also really
            # doesn't belong here. Whoever wants this should be working on
            # getting it into Plack::Test, or make a middleware out of it, or
            # whatever. Seriously - horrible.

            require HTML::HeadParser;

            my $parser = HTML::HeadParser->new();
            $parser->xml_mode(1) if $resp->content_is_xhtml;
            $parser->utf8_mode(1) if $] >= 5.008 && $HTML::Parser::VERSION >= 3.40;

            $parser->parse( $resp->content );
            my $h = $parser->header;
            for my $f ( $h->header_field_names ) {
                $resp->init_header( $f, [ $h->header($f) ] );
            }
            # Another horrible hack to make the response headers have a
            # 'status' field. This is for back-compat, but you should
            # call $resp->code instead!
            $resp->init_header('status', [ $resp->code ]);
        },
    }, @_);
}

my $agent;

sub _remote_request {
    require LWP::UserAgent;
    local $Plack::Test::Impl = 'ExternalServer';

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


    my $server = URI->new($ENV{CATALYST_SERVER});
    if ( $server->path =~ m|^(.+)?/$| ) {
        my $path = $1;
        $server->path("$path") if $path;    # need to be quoted
    }

    return _request({
        ua             => $agent,
        uri            => $server,
        mangle_request => sub {
            my ($request) = @_;

            # the request path needs to be sanitised if $server is using a
            # non-root path due to potential overlap between request path and
            # response path.
            if ($server->path) {
                # If request path is '/', we have to add a trailing slash to the
                # final request URI
                my $add_trailing = ($request->uri->path eq '/' || $request->uri->path eq '') ? 1 : 0;

                my @sp = split '/', $server->path;
                my @rp = split '/', $request->uri->path;
                shift @sp; shift @rp; # leading /
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
        },
    }, @_);
}

for my $name (qw(local_request remote_request)) {
    my $fun = sub {
        carp <<"EOW";
Calling Catalyst::Test::${name}() directly is deprecated.

Please import Catalyst::Test into your namespace and use the provided request()
function instead.
EOW
        return __PACKAGE__->can("_${name}")->(@_);
    };

    no strict 'refs';
    *$name = $fun;
}

sub _customize_request {
    my $request = shift;
    my $extra_env = shift;
    my $opts = pop(@_) || {};
    $opts = {} unless ref($opts) eq 'HASH';
    if ( my $host = exists $opts->{host} ? $opts->{host} : $default_host  ) {
        $request->header( 'Host' => $host );
    }

    if (my $extra = $opts->{extra_env}) {
        @{ $extra_env }{keys %{ $extra }} = values %{ $extra };
    }
}

=head2 action_ok($url [, $test_name ])

Fetches the given URL and checks that the request was successful. An optional
second argument can be given to specify the name of the test.

=head2 action_redirect($url [, $test_name ])

Fetches the given URL and checks that the request was a redirect. An optional
second argument can be given to specify the name of the test.

=head2 action_notfound($url [, $test_name ])

Fetches the given URL and checks that the request was not found. An optional
second argument can be given to specify the name of the test.

=head2 content_like( $url, $regexp [, $test_name ] )

Fetches the given URL and returns whether the content matches the regexp. An
optional third argument can be given to specify the name of the test.

=head2 contenttype_is($url, $type [, $test_name ])

Verify the given URL has a content type of $type and optionally specify a test name.

=head1 SEE ALSO

L<Catalyst>, L<Test::WWW::Mechanize::Catalyst>,
L<Test::WWW::Selenium::Catalyst>, L<Test::More>, L<HTTP::Request::Common>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=begin Pod::Coverage

local_request

remote_request

=end Pod::Coverage

=cut

1;
