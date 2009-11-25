use strict;
use warnings;
use Test::More;

use Pod::Coverage 0.19;
use Test::Pod::Coverage 1.04;

all_pod_coverage_ok(
  {
    also_private => ['BUILD']
  }
);

