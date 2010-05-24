use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";

use Test::More;
# "binmode STDOUT, ':utf8'" is insufficient, see http://code.google.com/p/test-more/issues/detail?id=46#c1
binmode Test::More->builder->output, ":utf8";
binmode Test::More->builder->failure_output, ":utf8";

use Catalyst::Test 'TestAppEncoding';

plan skip_all => 'This test does not run live'
    if $ENV{CATALYST_SERVER};

{   
    # Test for https://rt.cpan.org/Ticket/Display.html?id=53678
    # Catalyst::Test::get currently returns the raw octets, but it
    # would be more useful if it decoded the content based on the
    # Content-Type charset, as Test::WWW::Mechanize::Catalyst does
    use utf8;
    my $body = get('/utf8_non_ascii_content');
    utf8::decode($body);
    is $body, 'ʇsʎlɐʇɐɔ', 'Catalyst::Test::get returned content correctly UTF-8 encoded';
}

done_testing;
