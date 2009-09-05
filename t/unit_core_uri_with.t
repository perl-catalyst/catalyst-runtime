use strict;
use warnings;

use Test::More tests => 10;
use URI;

use_ok('Catalyst::Request');

my $request = Catalyst::Request->new( {
                uri => URI->new('http://127.0.0.1/foo/bar/baz')
              } );

is(
    $request->uri_with({}),
    'http://127.0.0.1/foo/bar/baz',
    'URI for absolute path'
);

is(
    $request->uri_with({ foo => 'bar' }),
    'http://127.0.0.1/foo/bar/baz?foo=bar',
    'URI adds param'
);

my $request2 = Catalyst::Request->new( {
                uri => URI->new('http://127.0.0.1/foo/bar/baz?bar=gorch')
              } );
is(
    $request2->uri_with({}),
    'http://127.0.0.1/foo/bar/baz?bar=gorch',
    'URI retains param'
);

is(
    $request2->uri_with({ me => 'awesome' }),
    'http://127.0.0.1/foo/bar/baz?bar=gorch&me=awesome',
    'URI retains param and adds new'
);

is(
    $request2->uri_with({ bar => undef }),
    'http://127.0.0.1/foo/bar/baz',
    'URI loses param when explicitly undef'
);

is(
    $request2->uri_with({ bar => 'snort' }),
    'http://127.0.0.1/foo/bar/baz?bar=snort',
    'URI changes param'
);

is(
    $request2->uri_with({ bar => [ 'snort', 'ewok' ] }),
    'http://127.0.0.1/foo/bar/baz?bar=snort&bar=ewok',
    'overwrite mode URI appends arrayref param'
);

is(
    $request2->uri_with({ bar => 'snort' }, { mode => 'append' }),
    'http://127.0.0.1/foo/bar/baz?bar=gorch&bar=snort',
    'append mode URI appends param'
);

is(
    $request2->uri_with({ bar => [ 'snort', 'ewok' ] }, { mode => 'append' }),
    'http://127.0.0.1/foo/bar/baz?bar=gorch&bar=snort&bar=ewok',
    'append mode URI appends arrayref param'
);

