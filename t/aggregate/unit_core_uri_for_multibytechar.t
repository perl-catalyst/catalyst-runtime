use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;

use_ok('TestApp');

my $base = 'http://127.0.0.1';

my $request = Catalyst::Request->new({
    base => URI->new($base),
    uri  => URI->new("$base/"),
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
is($context->uri_for('/', { name => '村瀬大輔' }), $uri_with_multibyte, 'uri_for with utf8 bytes query');
is($context->req->uri_with({ name => '村瀬大輔' }), $uri_with_multibyte, 'uri_with with utf8 bytes query');

# multibyte with utf8 string
is($context->uri_for('/', { name => "\x{6751}\x{702c}\x{5927}\x{8f14}" }), $uri_with_multibyte, 'uri_for with utf8 string query');
is($context->req->uri_with({ name => "\x{6751}\x{702c}\x{5927}\x{8f14}" }), $uri_with_multibyte, 'uri_with with utf8 string query');

# multibyte captures and args
my $action = $context->controller('Action::Chained')
    ->action_for('roundtrip_urifor_end');

{
use utf8;

is($context->uri_for($action, ['hütte'], 'hütte', {
    test => 'hütte'
}),
'http://127.0.0.1/chained/roundtrip_urifor/h%C3%BCtte/h%C3%BCtte?test=h%C3%BCtte',
'uri_for with utf8 captures and args');
}

done_testing;
