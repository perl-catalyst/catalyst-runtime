package TestApp::Controller::Priorities;

use strict;
use base 'Catalyst::Controller';

#
#   Local vs. Path (depends on definition order)
#

sub loc_vs_path1_loc :Path('/priorities/loc_vs_path1') { $_[1]->res->body( 'path' ) }
sub loc_vs_path1     :Local                            { $_[1]->res->body( 'local' ) }

sub loc_vs_path2     :Local                            { $_[1]->res->body( 'local' ) }
sub loc_vs_path2_loc :Path('/priorities/loc_vs_path2') { $_[1]->res->body( 'path' ) }

#
#   Local vs. index (has sub controller)
#

sub loc_vs_index :Local { $_[1]->res->body( 'local' ) }

#
#   Path vs. index (has sub controller)
#

sub path_vs_idx :Path('/priorities/path_vs_index') { $_[1]->res->body( 'path' ) }

1;
