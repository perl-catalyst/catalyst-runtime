use strict;
use warnings;
use Test::More;

use Pod::Coverage 0.19;
use Test::Pod::Coverage 1.04;

my @modules = all_modules;
our @private = ( 'BUILD' );
foreach my $module (@modules) {
    next if $module =~ /Unicode::Encoding/;
    local @private = (@private, 'run', 'dont_close_all_files') if $module =~ /^Catalyst::Script::/;
    local @private = (@private, 'plugin') if $module =~ /^Catalyst$/;
    local @private = (@private, 'snippets') if $module =~ /^Catalyst::Request$/;
    local @private = (@private, 'prepare_connection') if $module =~ /^Catalyst::Engine$/;

    pod_coverage_ok($module, {
        also_private   => \@private,
        coverage_class => 'Pod::Coverage::TrustPod',
    });
}

done_testing;

