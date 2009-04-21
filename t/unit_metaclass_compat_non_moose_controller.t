use Catalyst ();

{
    package TestApp::Controller::Base;
    use base qw/Catalyst::Controller/;
}
{
    package TestApp::Controller::Other;
    use base qw/TestApp::Controller::Base/;
}

Catalyst->setup_component('TestApp::Controller::Other');
Catalyst->setup_component('TestApp::Controller::Base');

use Test::More tests => 1;
use Test::Exception;

# Metaclass init order causes fail.
# There are TODO tests in Moose for this, see
# f2391d17574eff81d911b97be15ea51080500003
# after which the evil kludge in core can die in a fire.

lives_ok {
    TestApp::Controller::Base->get_action_methods
} 'Base class->get_action_methods ok when sub class initialized first';

