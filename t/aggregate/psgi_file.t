use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use File::Temp qw/ tempdir /;
use TestApp;
use File::Spec;
use Carp qw/croak/;
use IPC::Open3 qw(open3);

my $home = tempdir( CLEANUP => 1 );
my $path = File::Spec->catfile($home, 'testapp.psgi');
open(my $psgi, '>', $path)
    or die;
print $psgi q{
use strict;
use warnings;
use TestApp;

TestApp->psgi_app;
};
close($psgi);

open my $stdin, '<', File::Spec->devnull;
my $pid = open3 $stdin, my $stdout, undef, $^X, '-I', "$FindBin::Bin/../lib", '-c', $path;
my $output = do { local $/; <$stdout> };
waitpid $pid, 0;

ok $? == 0, '.psgi compiles'
  or diag $output;

# NOTE - YOU *CANNOT* do something like:
#my $psgi_ref = require $path;
# otherwise this test passes!
# I don't exactly know why that is yet, however, to be safe for future, that
# is why this test writes out its own .psgi file in a temp directory - so that that
# path has never been require'd before, and will never be require'd again..

local TestApp->config->{home} = $home;

my $failed = 0;
eval {
    # Catch infinite recursion (or anything else)
    local $SIG{__WARN__} = sub { warn(@_); $failed = 1; die; };
    TestApp->_finalized_psgi_app;
};
ok(!$@, 'No exception')
    or diag $@;
ok(!$failed, 'TestApp->_finalized_psgi_app works');

done_testing;
