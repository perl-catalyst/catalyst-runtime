package TestApp::View::Dump::False;

use strict;
use base qw[TestApp::View::Dump::Request];
use overload
    '""' => sub { undef; };

1;
