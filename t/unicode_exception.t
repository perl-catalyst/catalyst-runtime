#!perl
use utf8;
use strict;
use warnings;
use Test::More tests => 3;

use FindBin qw($Bin);
use lib "$Bin/lib";
use Catalyst::Test 'TestAppUnicodeException';
use Data::Dumper;
{
    my $res = request('/ok');
    is ($res->status_line, "200 OK");
    is ($res->content, '<h1>OK</h1>');
}
{
    my $res = request('/%E2%C3%83%C6%92%C3%8');
    is ($res->content, 'Bad unicode data') or diag Dumper($res);
}

