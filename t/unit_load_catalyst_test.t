#!perl

use strict;
use warnings;

use Test::More;

plan tests => 3;

use_ok('Catalyst::Test');

eval "get('http://localhost')";
isnt( $@, "", "get returns an error message with no app specified");

eval "request('http://localhost')";
isnt( $@, "", "request returns an error message with no app specified");
