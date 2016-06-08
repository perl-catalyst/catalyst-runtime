package TestAppArgsEmptyParens::Controller::Root;
$INC{'TestAppArgsEmptyParens/Controller/Root.pm'} = __FILE__;
use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub chain_base :Chained(/) PathPart('chain_base') CaptureArgs(0) { }

    sub args        : Chained(chain_base) PathPart('args')       Args   { $_[1]->res->body('Args') }
    sub args_empty  : Chained(chain_base) PathPart('args_empty') Args() { $_[1]->res->body('Args()') }

TestAppArgsEmptyParens::Controller::Root->config(namespace=>'');

package TestAppArgsEmptyParens;
$INC{'TestAppArgsEmptyParens.pm'} = __FILE__;

use Catalyst;
use TestLogger;

TestAppArgsEmptyParens->setup;
TestAppArgsEmptyParens->log( TestLogger->new );

1;
