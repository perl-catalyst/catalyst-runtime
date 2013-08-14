use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Test::More;
use Test::Fatal;

use Catalyst::Script::CGI;

local @ARGV;
is exception {
    Catalyst::Script::CGI->new_with_options(application_name => 'TestAppToTestScripts')->run;
}, undef, "new_with_options";
shift @TestAppToTestScripts::RUN_ARGS;
my $server = pop @TestAppToTestScripts::RUN_ARGS;
like ref($server), qr/^Plack::Handler/, 'Is a Plack::Handler';
is ref(delete($TestAppToTestScripts::RUN_ARGS[0]->{argv})), 'ARRAY';
is ref(delete($TestAppToTestScripts::RUN_ARGS[0]->{extra_argv})), 'ARRAY';
is_deeply \@TestAppToTestScripts::RUN_ARGS, [{}], "no args";

done_testing;
