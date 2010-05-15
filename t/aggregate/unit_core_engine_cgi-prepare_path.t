use strict;
use warnings;
use Test::More;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use TestApp;
use Catalyst::Engine::CGI;

# mod_rewrite to app root for non / based app
{
    my $r = get_req (0,
        REDIRECT_URL => '/comics/',
        SCRIPT_NAME => '/comics/dispatch.cgi',
        REQUEST_URI => '/comics/',
    );
    is ''.$r->uri, 'http://www.foo.com/comics/', 'uri is correct';
    is ''.$r->base, 'http://www.foo.com/comics/', 'base is correct';
}

# mod_rewrite to sub path under app root for non / based app
{
    my $r = get_req (0,
        PATH_INFO  => '/foo/bar.gif',
        REDIRECT_URL => '/comics/foo/bar.gif',
        SCRIPT_NAME => '/comics/dispatch.cgi',
        REQUEST_URI => '/comics/foo/bar.gif',
    );
    is ''.$r->uri, 'http://www.foo.com/comics/foo/bar.gif';
    is ''.$r->base, 'http://www.foo.com/comics/';
}

# Standard CGI hit for non / based app
{
    my $r = get_req (0,
        PATH_INFO => '/static/css/blueprint/screen.css',
        SCRIPT_NAME => '/~bobtfish/Gitalist/script/gitalist.cgi',
        REQUEST_URI => '/~bobtfish/Gitalist/script/gitalist.cgi/static/css/blueprint/screen.css',
    );
    is ''.$r->uri, 'http://www.foo.com/~bobtfish/Gitalist/script/gitalist.cgi/static/css/blueprint/screen.css';
    is ''.$r->base, 'http://www.foo.com/~bobtfish/Gitalist/script/gitalist.cgi/';
}
# / %2F %252F escaping case.
{
    my $r = get_req (1,
        PATH_INFO => '/%2F/%2F',
        SCRIPT_NAME => '/~bobtfish/Gitalist/script/gitalist.cgi',
        REQUEST_URI => '/~bobtfish/Gitalist/script/gitalist.cgi/%252F/%252F',
    );
    is ''.$r->uri, 'http://www.foo.com/~bobtfish/Gitalist/script/gitalist.cgi/%252F/%252F', 'uri correct';
    is ''.$r->base, 'http://www.foo.com/~bobtfish/Gitalist/script/gitalist.cgi/', 'base correct';
}

# Using rewrite rules to ask for a sub-path in your app.
# E.g. RewriteRule ^(.*)$ /path/to/fastcgi/domainprofi.fcgi/iframeredirect$1 [L,NS]
{
    my $r = get_req (0,
        PATH_INFO => '/iframeredirect/info',
        SCRIPT_NAME => '',
        REQUEST_URI => '/info',
    );
    is ''.$r->uri, 'http://www.foo.com/iframeredirect/info';
    is ''.$r->base, 'http://www.foo.com/';
}

# nginx example from espent with path /"foo"
{
    my $r = get_req (0,
        PATH_INFO => '"foo"',
        SCRIPT_NAME => '/',
        REQUEST_URI => '/%22foo%22',
    );
    is ''.$r->path, '%22foo%22';
    is ''.$r->uri, 'http://www.foo.com/%22foo%22';
    is ''.$r->base, 'http://www.foo.com/';
}

# nginx example from espent with path /"foo" and the app based at /oslobilder
{
    my $r = get_req (1,
        PATH_INFO => 'oslobilder/"foo"',
        SCRIPT_NAME => '/oslobilder/',
        REQUEST_URI => '/oslobilder/%22foo%22',
    );
    is ''.$r->path, '%22foo%22', 'path correct';
    is ''.$r->uri, 'http://www.foo.com/oslobilder/%22foo%22', 'uri correct';
    is ''.$r->base, 'http://www.foo.com/oslobilder/', 'base correct';
}

{
    local $TODO = 'Another mod_rewrite case';
    my $r = get_req (0,
        PATH_INFO => '/auth/login',
        SCRIPT_NAME => '/tx',
        REQUEST_URI => '/login',
    );
    is ''.$r->path, 'auth/login', 'path correct';
    is ''.$r->uri, 'http://www.foo.com/tx/auth/login', 'uri correct';
    is ''.$r->base, 'http://www.foo.com/tx/', 'base correct';
}

# test req->base and c->uri_for work correctly after an internally redirected request
# (i.e. REDIRECT_URL set) when the PATH_INFO contains a regex
{
    my $path = '/engine/request/uri/Rx(here)';
    my $r = get_req (0,
        SCRIPT_NAME => '/',
        PATH_INFO => $path,
        REQUEST_URI => $path,
        REDIRECT_URL => $path,
    );

    is $r->path, 'engine/request/uri/Rx(here)', 'URI contains correct path';
    is $r->base, 'http://www.foo.com/', 'Base is correct';
}


# FIXME - Test proxy logic
#       - Test query string
#       - Test non standard port numbers
#       - Test // in PATH_INFO
#       - Test scheme (secure request on port 80)

sub get_req {
    my $use_request_uri_for_path = shift;

    my %template = (
        HTTP_HOST => 'www.foo.com',
        PATH_INFO => '/',
    );

    local %ENV = (%template, @_);

    my $i = TestApp->new;
    $i->setup_finished(0);
    $i->config(use_request_uri_for_path => $use_request_uri_for_path);
    $i->setup_finished(1);
    $i->engine(Catalyst::Engine::CGI->new);
    $i->engine->prepare_path($i);
    return $i->req;
}

done_testing;

