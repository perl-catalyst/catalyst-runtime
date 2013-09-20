use strict;
use warnings;

use Test::More;

use Catalyst ();

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

sub fix_env {
    my (%input_env) = @_;

    my $mangled_env;
    my $app = Catalyst->apply_default_middlewares(sub {
        my ($env) = @_;
        $mangled_env = $env;
        return [ 200, ['Content-Type' => 'text/plain'], [''] ];
    });

    $app->({ %input_env, 'psgi.url_scheme' => 'http' });
    return %{ $mangled_env };
}

my %fixed_env = fix_env(%env);

is($fixed_env{PATH_INFO}, '/bar', 'check PATH_INFO');
ok(!exists($fixed_env{SCRIPT_NAME}) || !length($fixed_env{SCRIPT_NAME}),
    'check SCRIPT_NAME');

done_testing;
