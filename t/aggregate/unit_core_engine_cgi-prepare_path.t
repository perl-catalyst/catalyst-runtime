use strict;
use warnings;
use Test::More;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use TestApp;
use Catalyst::Engine::CGI;

{
    our %ENV = (
        HTTP_HOST => 'www.foo.com',
        REDIRECT_URL => '/comics/',
        PATH_INFO => '/',
        SCRIPT_NAME => '/comics/dispatch.cgi',
        REQUEST_URI => '/comics/',
    );
    my $i = TestApp->new;
    $i->engine(Catalyst::Engine::CGI->new);
    $i->engine->prepare_path($i);
    is ''.$i->req->uri, 'http://www.foo.com/comics/';
    is ''.$i->req->base, 'http://www.foo.com/comics/';
}

done_testing;

