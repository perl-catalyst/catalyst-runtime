use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Catalyst::Test 'ChainedActionsApp';
use Test::More;

plan 'skip_all' if $ENV{CATALYST_SERVER}; # This is not TestApp

content_like('/', qr/Application Home Page/, 'Application home');
content_like('/15/GoldFinger', qr/List project GoldFinger pages/, 'GoldFinger Project Index');
content_like('/15/GoldFinger/4/007', qr/This is 007 page of GoldFinger project/, '007 page in GoldFinger Project');
TODO: {
  local $TODO="Bug on precedence of dispatch order of chained actions.";
  content_like('/account', qr/New account o login/, 'no account');
  content_like('/account/ferz', qr/This is account ferz/, 'account');
  content_like('/account/123', qr/This is account 123/, 'account');
}
action_notfound('/c');

done_testing;

