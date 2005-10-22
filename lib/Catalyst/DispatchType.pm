package Catalyst::DispatchType;

use strict;

sub new {        # Dumbass constructor
    my ( $class, $attrs ) = @_;
    return bless { %{ $attrs || {} } }, $class;
}

sub prepare_action { die "Abstract method!"; }

sub register_action { return; }

1;
