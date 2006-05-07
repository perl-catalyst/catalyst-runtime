## ============================================================================
## Test to make sure that subclassed controllers (catalyst controllers
## that inherit from a custom base catalyst controller) don't experienc
## any namespace collision in the values under config.
## ============================================================================

use Test::More tests => 9;

use strict;
use warnings;

use_ok('Catalyst');

## ----------------------------------------------------------------------------
## First We define a base controller that inherits from Catalyst::Controller
## We add something to the config that we expect all children classes to
## be able to find.
## ----------------------------------------------------------------------------

{
	package base_controller;
	
	use base 'Catalyst::Controller';
	
	__PACKAGE__->config( base_key	=> 'base_value' );
}

## ----------------------------------------------------------------------------
## Next we instantiate two classes that inherit from the base controller.  We
## Add some local config information to these.
## ----------------------------------------------------------------------------

{
	package controller_a;

	use base 'base_controller';
	
	__PACKAGE__->config( key_a => 'value_a' );
}
	
	
{
	package controller_b;

	use base 'base_controller';

	__PACKAGE__->config( key_b => 'value_b' );
}

## Okay, we expect that the base controller has a config with one key
## and that the two children controllers inherit that config key and then
## add one more.  So the base controller has one config value and the two
## children each have two.

## ----------------------------------------------------------------------------
## THE TESTS.  Basically we first check to make sure that all the children of
## the base_controller properly inherit the {base_key => 'base_value'} info
## and that each of the children also has it's local config data and that none
## of the classes have data that is unexpected.
## ----------------------------------------------------------------------------


# First round, does everything have what we expect to find? If these tests fail there is something
# wrong with the way config is storing it's information.

ok( base_controller->config->{base_key} eq 'base_value', 'base_controller has expected config value for "base_key"') or
 diag('"base_key" defined as "'.base_controller->config->{base_key}.'" and not "base_value" in config');

ok( controller_a->config->{base_key} eq 'base_value', 'controller_a has expected config value for "base_key"') or
 diag('"base_key" defined as "'.controller_a->config->{base_key}.'" and not "base_value" in config');
 
ok( controller_a->config->{key_a} eq 'value_a', 'controller_a has expected config value for "key_a"') or
 diag('"key_a" defined as "'.controller_a->config->{key_a}.'" and not "value_a" in config');

ok( controller_b->config->{base_key} eq 'base_value', 'controller_b has expected config value for "base_key"') or
 diag('"base_key" defined as "'.controller_b->config->{base_key}.'" and not "base_value" in config');
 
ok( controller_b->config->{key_b} eq 'value_b', 'controller_b has expected config value for "key_b"') or
 diag('"key_b" defined as "'.controller_b->config->{key_b}.'" and not "value_b" in config');

# second round, does each controller have the expected number of config values? If this test fails there is
# probably some data collision between the controllers.

ok( scalar(keys %{base_controller->config}) == 1, 'base_controller has the expected number of config values') or
 diag("base_controller should have 1 config value, but it has ".scalar(keys %{base_controller->config}));
 
ok( scalar(keys %{controller_a->config}) == 2, 'controller_a has the expected number of config values') or
 diag("controller_a  should have 2 config value, but it has ".scalar(keys %{base_controller->config}));
 
ok( scalar(keys %{controller_b->config}) == 2, 'controller_b has the expected number of config values') or
 diag("controller_a should have 2 config value, but it has ".scalar(keys %{base_controller->config}));
