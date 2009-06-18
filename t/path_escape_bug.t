#!/usr/bin/env perl
use warnings;
use strict;
use Test::More qw/no_plan/;

{
    package TestApp;
    use parent qw/Catalyst/;
    use parent qw/Catalyst::Controller/;
    __PACKAGE__->setup();

    sub thing :Path {
        my ($self, $c, @path) = @_;
        $c->res->body(join "/", @path);
    }
    sub another :Path('something') {
        my ($self, $c) = @_;
        $c->forward('thing');
    }
    sub thing_uri :Path('thing_uri') {
        my ($self, $c, @path) = @_;
        $c->res->body($c->uri_for(@path));
    }
}

use_ok "Catalyst::Test", "TestApp";
my $req_path = 'foo/bar/baz quoxx{fnord}';
my $req = request("/$req_path");
ok($req->is_success, 'request succeeds');
is($req->content, $req_path, "returned path is identical to received path");
$req = request("/something/$req_path");
ok($req->is_success, 'request succeeds');
is($req->content, $req_path, "returned path is identical to received path 2");
$req = request("/thing_uri/$req_path");
ok($req->is_success, 'request succeeds');
is($req->content, "http://localhost/$req_path", "returned path is identical to received path 2");

