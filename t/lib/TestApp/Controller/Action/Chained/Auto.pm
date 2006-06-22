package TestApp::Controller::Action::Chained::Auto;
use warnings;
use strict;

use base qw( Catalyst::Controller );

#
#   Provided for sub-auto tests. This just always returns true.
#
sub auto    : Private { 1 }

#
#   Simple chains with auto actions returning 1 and 0
#
sub foo     : Chained PathPart('chained/autochain1') Captures(1) { }
sub bar     : Chained PathPart('chained/autochain2') Captures(1) { }

#
#   Detaching out of an auto action.
#
sub dt1     : Chained PathPart('chained/auto_detach') Captures(1) { }

#
#   Forwarding out of an auto action.
#
sub fw1     : Chained PathPart('chained/auto_forward') Captures(1) { }

#
#   Target for dispatch and forward tests.
#
sub fw3     : Private { }

1;
