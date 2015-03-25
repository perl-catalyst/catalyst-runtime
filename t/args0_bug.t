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

    sub chained_one_args_0  : Chained(chain_base) PathPart('') Args(1) { $_[1]->res->body('chained_one_args_0') }
    sub chained_one_args_1  : Chained(chain_base) PathPart('') Args(1) { $_[1]->res->body('chained_one_args_1') }

    sub chained_zero_args_0 : Chained(chain_base) PathPart('') Args(0) { $_[1]->res->body('chained_zero_args_0') }
    sub chained_zero_args_1 : Chained(chain_base) PathPart('') Args(0) { $_[1]->res->body('chained_zero_args_1') }

  MyApp::Controller::Root->config(namespace=>'');

  package MyApp;
  use Catalyst;

  #MyApp->config(use_chained_args_0_special_case=>1);
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
   my $res = request '/chain_base/capturearg/arg';
  is $res->content, 'chained_one_args_1', "request '/chain_base/capturearg/arg'";
}

{
    my $res = request '/chain_base/capturearg';
    is $res->content, 'chained_zero_args_1', "request '/chain_base/capturearg'";
}

done_testing;

__END__

