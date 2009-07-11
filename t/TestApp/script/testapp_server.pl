#!/usr/bin/env perl

use FindBin qw/$Bin/;
BEGIN { 
    $ENV{CATALYST_ENGINE} ||= 'HTTP';
    $ENV{CATALYST_SCRIPT_GEN} = 31;
    require Catalyst::Engine::HTTP;
} 

## because this is a test
use lib "$Bin/../../../lib";
use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('TestApp','Server');
