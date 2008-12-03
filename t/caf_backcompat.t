use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;
use Catalyst::Action;

my $action=Catalyst::Action->new({foo=>'bar'});

is $action->{foo}, 'bar', 'custom Action attribute';
