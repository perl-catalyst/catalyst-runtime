package TestMiddlewareFromConfig;

use Catalyst qw/ConfigLoader/;

## Proof this is good config
##__PACKAGE__->config( do TestMiddlewareFromConfig->path_to('testmiddlewarefromconfig.pl') );

__PACKAGE__->setup_middleware('Head');
__PACKAGE__->setup;

