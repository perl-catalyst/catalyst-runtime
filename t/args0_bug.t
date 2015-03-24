use warnings;
use strict;
use Test::More;

{
  package MyApp::Controller::Root;
  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  use Moose;
  use MooseX::MethodAttributes;

  extends 'Catalyst::Controller';

  sub chain_base :Chained(/) CaptureArgs(1) { }

    sub chained_zero_args_0 : Chained(chain_base) PathPart('') Args(0) { $_[1]->res->body('chained_zero_args_0') }
    sub chained_zero_args_1 : Chained(chain_base) PathPart('') Args(0) { $_[1]->res->body('chained_zero_args_1') }

    sub chained_one_args_0  : Chained(chain_base) PathPart('') Args(1) { $_[1]->res->body('chained_one_args_0') }
    sub chained_one_args_1  : Chained(chain_base) PathPart('') Args(1) { $_[1]->res->body('chained_one_args_1') }

  MyApp::Controller::Root->config(namespace=>'');

  package MyApp;
  use Catalyst;

  MyApp->setup;
}

=over

[debug] Loaded Chained actions:
.-----------------------------------------+---------------------------------------------------.
| Path Spec                               | Private                                           |
+-----------------------------------------+---------------------------------------------------+
| /chain_base/*/*                         | /chain_base (1)                                   |
|                                         | => /chained_one_args_0 (1)                        |
| /chain_base/*/*                         | /chain_base (1)                                   |
|                                         | => /chained_one_args_1 (1)                        |
| /chain_base/*                           | /chain_base (1)                                   |
|                                         | => /chained_zero_args_0 (0)                       |
| /chain_base/*                           | /chain_base (1)                                   |
|                                         | => /chained_zero_args_1 (0)                       |
'-----------------------------------------+---------------------------------------------------'

=cut

use Catalyst::Test 'MyApp';

{
    # Generally if more than one action can match and the path length is equal, we expect
    # the dispatcher to just take the first one.  So this works as expected.
    my $res = request '/chain_base/capturearg/arg';
    is $res->content, 'chained_one_args_1', "request '/chain_base/capturearg/arg'";
}

{
    # However this doesn't pass :(  For some reason when Args(0), we take the last one that
    # matches...
    my $res = request '/chain_base/capturearg';
    is $res->content, 'chained_zero_args_1', "request '/chained_one_args_0/capturearg/arg'";
}

done_testing;
