use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/lib";
use Test::More;
use File::Spec;
BEGIN { # Shut up debug output, app needs debug on for the issue to
        # appear, but we don't want the spraff to the screen

    my $devnull = File::Spec->devnull;
    open my $fh, '>', $devnull or die "Cannot write to $devnull: $!";

    *STDERR = $fh;
}

use Catalyst::Test 'TestAppShowInternalActions';

my $last_warning;
{
    local $SIG{__WARN__} = sub { $last_warning = shift };
    my $res = get('/');
}

# FIXME - is this test really useful?
# it doesn't change anything if we remove the show_internal_actions => 1 line
# from TestAppShowInternalActions
is( $last_warning, undef, 'there should be no warnings about uninitialized value' );

done_testing;
