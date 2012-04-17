#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;
use Catalyst::Test 'TestApp';

my $types = {
    #zip => ['Archive::Zip',  464, qr/^PK\x03\x04.*[\x80-\xFF]+.*x.txt/s],
    ### Archive::Zip currently unreliable as a test platform until RT #54827 is fixed and popularized ###
    ### https://rt.cpan.org/Ticket/Display.html?id=54827 ###
    
    csv => ['Text::CSV',      96, qr/"Banana \(single\)","\$ \.40"$/m],
    xml => ['XML::Simple',  1657, qr(</geocode>)],
};

plan tests => scalar keys %$types;

for my $action ( keys %$types ) {
    my ($module, $length, $regexp) = @{$types->{$action}};
    
    subtest uc($action)." Set" => sub {
        undef $@;
        eval "require $module";  # require hates string class names; must use eval string instead of block
        print $@;
        plan ($@ ? (skip_all => $module.' not installed') : (tests => 4) );
    
        ok( my $response = request('http://localhost/engine/response/perlio/' . $action ), "Request" );
        ok( $response->is_success, "Response Successful 2xx" );
        is( length( $response->content ), $length, "Length OK" );
        like( $response->content, $regexp, "RegExp Check OK" );
        done_testing();
    };
}

done_testing();
