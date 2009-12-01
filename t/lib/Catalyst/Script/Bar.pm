package Catalyst::Script::Bar;
use Moose;
use namespace::autoclean;

with 'Catalyst::ScriptRole';

sub run { __PACKAGE__ }

1;
