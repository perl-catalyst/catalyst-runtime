# Test case for Chained Actions

#

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Catalyst::Test 'ChainedActionsApp';
use Test::More tests => 2;

content_like('/', qr/Application Home Page/, 'Application home');
content_like('/account/123', qr/This is account 123/, 'account');
