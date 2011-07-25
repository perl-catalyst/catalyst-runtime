use strict;
use warnings;
use FindBin qw/$Bin/;
use Test::More;
use Test::Without::Module qw(
    Starman
    Plack::Handler::Starman
    MooseX::Daemonize
    MooseX::Daemonize::Pid::File
    MooseX::Daemonize::Core
);
require "$Bin/../aggregate/unit_core_script_server.t";

1;

