#!perl

use strict;
use warnings;

use Test::More;

eval "use FCGI";
plan skip_all => 'FCGI required' if $@;

plan tests => 2;

require Catalyst::Engine::FastCGI;

my %env = (
    'SCRIPT_NAME'          => '/bar',
    'SERVER_NAME'          => 'localhost:8000',
    'HTTP_ACCEPT_ENCODING' => 'gzip,deflate',
    'HTTP_CONNECTION'      => 'keep-alive',
    'PATH_INFO'            => '',
    'HTTP_ACCEPT'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'REQUEST_METHOD'       => 'GET',
    'SCRIPT_FILENAME'      => '/tmp/Foo/root/bar',
    'HTTP_ACCEPT_CHARSET'  => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
    'SERVER_SOFTWARE'      => 'lighttpd/1.4.15',
    'QUERY_STRING'         => '',
    'REMOTE_PORT'          => '22207',
    'SERVER_PORT'          => 8000,
    'REDIRECT_STATUS'      => '200',
    'HTTP_ACCEPT_LANGUAGE' => 'en-us,en;q=0.5',
    'REMOTE_ADDR'          => '127.0.0.1',
    'FCGI_ROLE'            => 'RESPONDER',
    'HTTP_KEEP_ALIVE'      => '300',
    'SERVER_PROTOCOL'      => 'HTTP/1.1',
    'REQUEST_URI'          => '/bar',
    'GATEWAY_INTERFACE'    => 'CGI/1.1',
    'SERVER_ADDR'          => '127.0.0.1',
    'DOCUMENT_ROOT'        => '/tmp/Foo/root',
    'HTTP_HOST'            => 'localhost:8000',
);

Catalyst::Engine::FastCGI->_fix_env(\%env);

is($env{PATH_INFO}, '/bar', 'check PATH_INFO');
ok(!exists($env{SCRIPT_NAME}), 'check SCRIPT_NAME');

