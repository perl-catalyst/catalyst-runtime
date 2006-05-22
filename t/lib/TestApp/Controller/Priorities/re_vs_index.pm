package TestApp::Controller::Priorities::re_vs_index;

use strict;
use base 'Catalyst::Base';

sub index :Private { $_[1]->res->body( 'index' ) }

1;
