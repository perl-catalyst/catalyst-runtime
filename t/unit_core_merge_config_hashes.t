use strict;
use warnings;

use Test::More;

my @tests = (
    {
        given   => [ { a => 1 }, { b => 1 } ],
        expects => { a => 1, b => 1 }
    },
    {
        given   => [ { a => 1 }, { a => { b => 1 } } ],
        expects => { a => { b => 1 } }
    },
    {
        given   => [ { a => { b => 1 } }, { a => 1 } ],
        expects => { a => 1 }
    },
    {
        given   => [ { a => 1 }, { a => [ 1 ] } ],
        expects => { a => [ 1 ] }
    },
    {
        given   => [ { a => [ 1 ] }, { a => 1 } ],
        expects => { a => 1 }
    },
    {
        given   => [ { a => { b => 1 } }, { a => { b => 2 } } ],
        expects => { a => { b => 2 } }
    },
    {
        given   => [ { a => { b => 1 } }, { a => { c => 1 } } ],
        expects => { a => { b => 1, c => 1 } }
    },
);

plan tests => scalar @tests + 1;

use_ok('Catalyst');

for my $test ( @ tests ) {
    is_deeply( Catalyst->merge_config_hashes( @{ $test->{ given } } ), $test->{ expects } );
}
