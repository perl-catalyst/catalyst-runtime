# live_fork.t
# Copyright (c) 2006 Jonathan Rockway <jrockway@cpan.org>

=head1 SYNOPSIS

Tests if Catalyst can fork/exec other processes successfully

=cut
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use Catalyst::Test qw(TestApp);

eval 'use YAML';
plan skip_all => 'YAML required' if $@;

plan skip_all => 'Using remote server (and REMOTE_FORK not set)'
    if $ENV{CATALYST_SERVER} && !$ENV{REMOTE_FORK};

plan skip_all => 'Skipping fork tests: no /bin/ls'
    if !-e '/bin/ls'; # see if /bin/ls exists

{
    ok(my $result = get('/fork/system/%2Fbin%2Fls'), 'system');

    if (my $result_ref = result_ok($result)) {
        ok($result_ref, 'is YAML');
        is($result_ref->{result}, 0, 'exited OK');
    }
}

{
    ok(my $result = get('/fork/backticks/%2Fbin%2Fls'), '`backticks`');

    if (my $result_ref = result_ok($result)) {
        ok($result_ref, 'is YAML');
        is($result_ref->{code}, 0, 'exited successfully');
        like($result_ref->{result}, qr{^/bin/ls[^:]}, 'contains ^/bin/ls$');
        like($result_ref->{result}, qr{\n.*\n}m, 'contains two newlines');
    }
}

{
    ok(my $result = get('/fork/fork'), 'fork');

    if (my $result_ref = result_ok($result)) {
        ok($result_ref, 'is YAML');
        isnt($result_ref->{pid}, 0, q{fork's "pid" wasn't 0});
        isnt($result_ref->{pid}, $$, 'fork got a new pid');
        is($result_ref->{result}, 'ok', 'fork was effective');
    }
}

sub result_ok {
    my $result = shift;

    unlike( $result, qr/FATAL/, 'result is not an error' )
        or return;

    $result =~ s/\r\n|\r/\n/g;

    return eval { Load($result) };
}

done_testing;
