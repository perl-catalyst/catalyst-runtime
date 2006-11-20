#!/usr/bin/perl
# live_fork.t 
# Copyright (c) 2006 Jonathan Rockway <jrockway@cpan.org>

=head1 SYNOPSIS

Tests if Catalyst can fork/exec other processes successfully

=cut
use strict;
use warnings;
use Test::More;
use YAML;
use FindBin;
use lib "$FindBin::Bin/lib";
use Catalyst::Test qw(TestApp);

plan 'skip_all' if !-e '/bin/ls'; # see if /bin/ls exists
plan tests => 8; # otherwise

{
  fork:
    ok(my $result = get('/fork/fork/%2Fbin%2Fls'), 'get /fork//bin/ls');
    my @result = split /$/m, $result;
    $result = join q{}, @result[-4..-1];
    
    my $result_ref = eval { Load($result) };
    ok($result_ref, 'is YAML');
    is($result_ref->{code}, 0, 'exited successfully');
    like($result_ref->{result}, qr{^/bin/ls[^:]}, 'contains ^/bin/ls$');
}

{ 
  backticks:
    ok(my $result = get('/fork/backticks/%2Fbin%2Fls'), 'get /fork//bin/ls');
    my @result = split /$/m, $result;
    $result = join q{}, @result[-4..-1];
    
    my $result_ref = eval { Load($result) };
    ok($result_ref, 'is YAML');
    is($result_ref->{code}, 0, 'exited successfully');
    like($result_ref->{result}, qr{^/bin/ls[^:]}, 'contains ^/bin/ls$');
}
