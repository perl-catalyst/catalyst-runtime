package TestAppComponent;
use Moose;
use Catalyst;
extends q/Catalyst/;

{
    no warnings 'redefine';
    local *Catalyst::Log::warn = sub {};
    __PACKAGE__->setup;
}

1;
