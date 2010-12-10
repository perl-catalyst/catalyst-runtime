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

content_like('/account', qr/New account o login/, 'no account');
content_like('/account/ferz', qr/This is account ferz/, 'account');
content_like('/account/123', qr/This is account 123/, 'account');
content_like('/account/profile/007/James Bond', qr/This is profile of James Bond/, 'account');

TODO: {
      local $TODO = q(new chained action test case that fails yet.);
      content_like('/downloads/', qr/This is downloads index/, 'downloads');
}

action_notfound('/c');

done_testing;

