use strict;
use warnings;
use Test::More;
use Test::Exception;

use Catalyst::Engine;

my $m = sub { Catalyst::Engine->_dump_error_page_element(@_) };

lives_ok { $m->('Scalar' => ['foo' => 'bar']) };
lives_ok { $m->('Array' => ['foo' => []]) };
lives_ok { $m->('Hash' => ['foo' => {}]) }; 

done_testing;

