package TestAppShowInternalActions;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

use Catalyst qw/ -Debug /; # Debug must remain on for
                           # t/live_show_internal_actions_warnings.t

extends 'Catalyst';

__PACKAGE__->config(
    name => 'TestAppShowInternalActions',
    disable_component_resolution_regex_fallback => 1,
    show_internal_actions => 1,
);

__PACKAGE__->setup();

1;
