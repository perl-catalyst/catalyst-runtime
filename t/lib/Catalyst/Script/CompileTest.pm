package Catalyst::Script::CompileTest;
use Moose;
use namespace::autoclean;

use Test::More;

with 'Catalyst::ScriptRole';

sub run { __PACKAGE__ }

after new_with_options => sub {
    my ($self, %args) = @_;
    is_deeply \%args, { application_name => 'ScriptTestApp' }, 'App name correct';
};

1;
