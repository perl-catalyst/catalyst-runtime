use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Test::More tests => 2;
use Test::Fatal;

is exception {
    require TestAppClassExceptionSimpleTest;
}, undef, 'Can load application';


is exception {
    Catalyst::Exception->throw
}, undef, 'throw is properly stubbed out';



