package TestMiddlewareFromPlugin;

use Catalyst qw/+TestMiddlewareFromPlugin::SetMiddleware/;

## Proof this is good config
##__PACKAGE__->config( do TestMiddlewareFromConfig->path_to('testmiddlewarefromplugin.pl') );

__PACKAGE__->setup_middleware('Head');
__PACKAGE__->setup;

1;
