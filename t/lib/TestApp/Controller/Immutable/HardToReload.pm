package TestApp::Controller::Immutable::HardToReload;
use Moose;
BEGIN { extends 'Catalyst::Controller' }
no Moose;
__PACKAGE__->meta->make_immutable;

package # Standard PAUSE hiding technique
    TestApp::Controller::Immutable::HardToReload::PAUSEHide;
use Moose;
BEGIN { extends 'Catalyst::Controller' }
no Moose;
__PACKAGE__->meta->make_immutable;

# Not an inner package
package TestApp::Controller::Immutable2;
use Moose;
BEGIN { extends 'Catalyst::Controller' }
no Moose;
__PACKAGE__->meta->make_immutable;

# Not even in the app namespace
package Frobnitz;
use Moose;
BEGIN { extends 'Catalyst::Controller' }
no Moose;
__PACKAGE__->meta->make_immutable;
