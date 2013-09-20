use strict;
use warnings;
use Test::More;
use Test::Fatal;

use Catalyst::Engine;

my $m = sub { Catalyst::Engine->_dump_error_page_element(@_) };

is exception { $m->('Scalar' => ['foo' => 'bar']) }, undef;
is exception { $m->('Array' => ['foo' => []]) }, undef;
is exception { $m->('Hash' => ['foo' => {}]) }, undef;

done_testing;

