#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use Test::More tests => 1;
use Catalyst::Test 'TestApp';

{
  # Allow overriding automatic root.
  is(TestApp->config->{root},'/Users/chansen/src/MyApp/root');
}
