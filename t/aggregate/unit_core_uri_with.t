use strict;
use warnings;

use Test::More;
use URI;
use Catalyst::Log;

use_ok('Catalyst::Request');

sub cmp_uri {
    my ($got, $exp_txt, $comment) = @_;
    $comment ||= '';
    my $exp = URI->new($exp_txt);
    foreach my $thing (qw/ scheme host path /) {
        is $exp->$thing, $got->$thing, "$comment: $thing";
    }
    my %got_q = map { split /=/ } split /\&/, ($got->query||'');
    my %exp_q = map { split /=/ } split /\&/, ($exp->query||'');
    is_deeply \%got_q, \%exp_q, "$comment: query";
}

my $request = Catalyst::Request->new( {
                _log => Catalyst::Log->new,
                uri => URI->new('http://127.0.0.1/foo/bar/baz')
              } );

cmp_uri(
    $request->uri_with({}),
    'http://127.0.0.1/foo/bar/baz',
    'URI for absolute path'
);

cmp_uri(
    $request->uri_with({ foo => 'bar' }),
    'http://127.0.0.1/foo/bar/baz?foo=bar',
    'URI adds param'
);

my $request2 = Catalyst::Request->new( {
                _log => Catalyst::Log->new,
                uri => URI->new('http://127.0.0.1/foo/bar/baz?bar=gorch')
              } );

cmp_uri(
    $request2->uri_with({}),
    'http://127.0.0.1/foo/bar/baz?bar=gorch',
    'URI retains param'
);

cmp_uri(
    $request2->uri_with({ me => 'awesome' }),
    'http://127.0.0.1/foo/bar/baz?bar=gorch&me=awesome',
    'URI retains param and adds new'
);

cmp_uri(
    $request2->uri_with({ bar => undef }),
    'http://127.0.0.1/foo/bar/baz',
    'URI loses param when explicitly undef'
);

cmp_uri(
    $request2->uri_with({ bar => 'snort' }),
    'http://127.0.0.1/foo/bar/baz?bar=snort',
    'URI changes param'
);

cmp_uri(
    $request2->uri_with({ bar => [ 'snort', 'ewok' ] }),
    'http://127.0.0.1/foo/bar/baz?bar=snort&bar=ewok',
    'overwrite mode URI appends arrayref param'
);

cmp_uri(
    $request2->uri_with({ bar => 'snort' }, { mode => 'append' }),
    'http://127.0.0.1/foo/bar/baz?bar=gorch&bar=snort',
    'append mode URI appends param'
);

cmp_uri(
    $request2->uri_with({ bar => [ 'snort', 'ewok' ] }, { mode => 'append' }),
    'http://127.0.0.1/foo/bar/baz?bar=gorch&bar=snort&bar=ewok',
    'append mode URI appends arrayref param'
);

done_testing;

