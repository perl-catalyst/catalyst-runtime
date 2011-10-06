package TestApp::Controller::Action::ConfigSmashArrayRefs;

use strict;
use base 'Catalyst::Controller';

 sub foo : Action {}

# check configuration for an inherited action
__PACKAGE__->config(
    action => {
        foo => { CustomAttr => [ 'Bar' ] }
    }
);

sub _parse_CustomAttr_attr {
    my ($self, $app, $name, $value) = @_;
    return CustomAttr => "PoopInYourShoes";
}


1;

