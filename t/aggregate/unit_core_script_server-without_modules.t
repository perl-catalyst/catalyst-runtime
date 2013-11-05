use strict;
use warnings;
use FindBin qw/$Bin/;

# Package::Stash::XS has a weird =~ XS invocation during its compilation
# This interferes with @INC hooks that do rematcuing on their own on
# perls before 5.8.7. Just use the PP version to work around this.
BEGIN { $ENV{PACKAGE_STASH_IMPLEMENTATION} = 'PP' if $] < '5.008007' }

use Test::More;
use Try::Tiny;

plan skip_all => "Need Test::Without::Module for this test"
    unless try { require Test::Without::Module; 1 };

Test::Without::Module->import(qw(
    Starman::Server
    Plack::Handler::Starman
    MooseX::Daemonize
    MooseX::Daemonize::Pid::File
    MooseX::Daemonize::Core
));

require "$Bin/../aggregate/unit_core_script_server.t";

Test::Without::Module->unimport(qw(
    Starman::Server
    Plack::Handler::Starman
    MooseX::Daemonize
    MooseX::Daemonize::Pid::File
    MooseX::Daemonize::Core
));

1;

