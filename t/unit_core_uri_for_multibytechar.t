use strict;
use warnings;

use FindBin;
use File::Spec;
use lib File::Spec->catfile($FindBin::Bin, 'lib');

use Test::More;

plan tests => 3;

use_ok('TestApp');

my $base = 'http://127.0.0.1';

my $request = Catalyst::Request->new({
    base => URI->new($base),
});

my $context = TestApp->new({
    request => $request,
});


my $uri_with_multibyte = URI->new($base);
$uri_with_multibyte->path('/');
$uri_with_multibyte->query_form(
    name => '村瀬大輔',
);


# multibyte with utf8 bytes
is($context->uri_for('/', { name => '村瀬大輔' }), $uri_with_multibyte, 'uri with utf8 bytes query');


# multibyte with utf8 string
is($context->uri_for('/', { name => "\x{6751}\x{702c}\x{5927}\x{8f14}" }), $uri_with_multibyte, 'uri with utf8 string query');
