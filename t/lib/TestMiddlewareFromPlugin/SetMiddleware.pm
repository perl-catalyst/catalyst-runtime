package TestMiddlewareFromPlugin::SetMiddleware;
use strict;
use warnings;
use File::Spec;
use File::Basename ();

my $config_path = File::Spec->catfile(File::Basename::dirname(__FILE__), 'testmiddlewarefromplugin.pl');

sub setup {
    my $c = shift;
    $c->config(do $config_path);
    $c->next::method(@_);
}

1;
