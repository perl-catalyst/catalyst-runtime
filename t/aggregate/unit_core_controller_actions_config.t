use strict;
use warnings;
use Test::More;
use FindBin qw/ $Bin /;
use lib "$Bin/../lib";

use TestApp;

is(TestApp->controller("Action::ConfigSmashArrayRefs")->config->{action}{foo}{CustomAttr}[0], 'Bar', 'Config un-mangled. RT#65463');

done_testing;

