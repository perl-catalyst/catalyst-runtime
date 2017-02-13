use strict;
use warnings;
use FindBin qw/$Bin/;

# Package::Stash::XS has a weird =~ XS invocation during its compilation
# This interferes with @INC hooks that do rematcuing on their own on
# perls before 5.8.7. Just use the PP version to work around this.
BEGIN { $ENV{PACKAGE_STASH_IMPLEMENTATION} = 'PP' if $] < '5.008007' }

use Test::More;
use Try::Tiny;

my %hidden = map { (my $m = "$_.pm") =~ s{::}{/}g; $m => 1 } qw(
    Starman::Server
    Plack::Handler::Starman
    MooseX::Daemonize
    MooseX::Daemonize::Pid::File
    MooseX::Daemonize::Core
);
local @INC = (sub {
  return unless exists $hidden{$_[1]};
  die "Can't locate $_[1] in \@INC (hidden)\n";
}, @INC);

do "$Bin/../aggregate/unit_core_script_server.t"
  or die $@ || 'test returned false';

1;
