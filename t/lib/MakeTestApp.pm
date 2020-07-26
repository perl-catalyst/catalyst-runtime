package MakeTestApp;
use strict;
use warnings;

use Exporter 'import';
use Cwd qw(abs_path);
use File::Spec::Functions qw(updir catdir);
use File::Basename qw(dirname);
use File::Path qw(rmtree);
use File::Copy::Recursive qw(dircopy);

our @EXPORT = qw(make_test_app);

our $root = abs_path(catdir(dirname(__FILE__), (updir) x 2));

sub make_test_app {
    my $tmp = "$root/t/tmp";
    rmtree $tmp if -d $tmp;
    mkdir $tmp;

    # create a TestApp and copy the test libs into it
    my $testapp = "$tmp/TestApp";
    mkdir $testapp;

    mkdir "$testapp/lib";
    mkdir "$testapp/script";

    for my $command (qw(CGI FastCGI Server)) {
        my $script = "$testapp/script/testapp_\L$command\E.pl";
        open my $fh, '>:raw', $script
            or die "can't create $script: $!";
        print $fh <<"END_CODE";
#!/usr/bin/env perl

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('TestApp', '$command');

1;
END_CODE
        close $fh;
        chmod 0755, $script;
    }

    open my $fh, '>:raw', "$testapp/cpanfile";
    close $fh;

    File::Copy::Recursive::dircopy( "$root/t/lib", "$testapp/lib" );

    return $testapp;
}

1;
