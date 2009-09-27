use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 1;
use Test::Exception;
use TestAppNonMooseController;

# Metaclass init order causes fail.
# There are TODO tests in Moose for this, see
# f2391d17574eff81d911b97be15ea51080500003
# after which the evil kludge in core can die in a fire.

lives_ok {
    TestAppNonMooseController::ControllerBase->get_action_methods
} 'Base class->get_action_methods ok when sub class initialized first';

