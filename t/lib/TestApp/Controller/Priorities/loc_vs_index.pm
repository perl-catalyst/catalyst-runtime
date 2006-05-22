package TestApp::Controller::Priorities::loc_vs_index;

use strict;
use base 'Catalyst::Base';

sub index :Private { $_[1]->res->body( 'index' ) }

1;
