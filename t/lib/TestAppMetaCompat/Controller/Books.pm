package TestAppMetaCompat::Controller::Books;

use strict;
use base qw/TestAppMetaCompat::Controller::Base/;

sub edit : Local ActionClass('+Catalyst::Controller::FormBuilder::Action') {
}

1;
