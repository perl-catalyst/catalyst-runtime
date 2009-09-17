use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";

use Test::More 'no_plan';
use Test::Exception;

use Catalyst::Script::Server;

{
    local @ARGV; # Blank
    local @TestAppToTestScripts::RUN_ARGS;
    lives_ok {
        Catalyst::Script::Server->new_with_options(application_name => 'TestAppToTestScripts')->run;
    };
    is_deeply \@TestAppToTestScripts::RUN_ARGS, ['TestAppToTestScripts',
          '3000',
          'localhost',
          {
            'pidfile' => undef,
            'fork' => undef,
            'follow_symlinks' => undef,
            'background' => undef,
            'keepalive' => undef
          }];
}

{
    local @ARGV = qw/-p 3001/;
    local @TestAppToTestScripts::RUN_ARGS;
    lives_ok {
        Catalyst::Script::Server->new_with_options(application_name => 'TestAppToTestScripts')->run;
    };
    is_deeply \@TestAppToTestScripts::RUN_ARGS, ['TestAppToTestScripts',
          '3001',
          'localhost',
          {
            'pidfile' => undef,
            'fork' => undef,
            'follow_symlinks' => undef,
            'background' => undef,
            'keepalive' => undef
          }];
}
