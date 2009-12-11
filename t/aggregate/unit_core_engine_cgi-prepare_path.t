use strict;
use warnings;
use Test::More;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use TestApp;
use Catalyst::Engine::CGI;

our %template = (
    HTTP_HOST => 'www.foo.com',
    PATH_INFO => '/',
);

# mod_rewrite to app root for non / based app
{
    my $r = get_req (
        REDIRECT_URL => '/comics/',
        SCRIPT_NAME => '/comics/dispatch.cgi',
        REQUEST_URI => '/comics/',
    );
    is ''.$r->uri, 'http://www.foo.com/comics/';
    is ''.$r->base, 'http://www.foo.com/comics/';
}

# mod_rewrite to sub path under app root for non / based app
{
    my $r = get_req (
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
    my $r = get_req (
        PATH_INFO => '/static/css/blueprint/screen.css',
        SCRIPT_NAME => '/~bobtfish/Gitalist/script/gitalist.cgi',
        REQUEST_URI => '/~bobtfish/Gitalist/script/gitalist.cgi/static/css/blueprint/screen.css',
    );
    is ''.$r->uri, 'http://www.foo.com/~bobtfish/Gitalist/script/gitalist.cgi/static/css/blueprint/screen.css';
    is ''.$r->base, 'http://www.foo.com/~bobtfish/Gitalist/script/gitalist.cgi/';
}
# / %2F %252F escaping case.
{
    my $r = get_req (
        PATH_INFO => '/%2F/%2F',
        SCRIPT_NAME => '/~bobtfish/Gitalist/script/gitalist.cgi',
        REQUEST_URI => '/~bobtfish/Gitalist/script/gitalist.cgi/%252F/%252F',
    );
    is ''.$r->uri, 'http://www.foo.com/~bobtfish/Gitalist/script/gitalist.cgi/%252F/%252F';
    is ''.$r->base, 'http://www.foo.com/~bobtfish/Gitalist/script/gitalist.cgi/';
}

# FIXME - Test proxy logic
#       - Test query string
#       - Test non standard port numbers
#       - Test // in PATH_INFO
#       - Test scheme (secure request on port 80)

sub get_req {
    local %ENV = (%template, @_);
    my $i = TestApp->new;
    $i->engine(Catalyst::Engine::CGI->new);
    $i->engine->prepare_path($i);
    return $i->req;
}

done_testing;

