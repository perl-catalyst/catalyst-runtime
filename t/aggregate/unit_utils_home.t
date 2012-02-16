use strict;
use warnings;

use Test::More;
use File::Temp qw/ tempdir /;
use Catalyst::Utils;
use File::Spec;
use Path::Class qw/ dir /;
use Cwd qw/ cwd /;

my @dists = Catalyst::Utils::dist_indicator_file_list();
is(scalar(@dists), 3, 'Makefile.PL Build.PL dist.ini');

my $cwd = cwd();
foreach my $inc ('', 'lib', 'blib'){
    my $d = tempdir(CLEANUP => 1);
    chdir($d);
    local $INC{'MyApp.pm'} = File::Spec->catdir($d, $inc, 'MyApp.pm');
    ok !Catalyst::Utils::home('MyApp'), "No files found inc $inc";
    open(my $fh, '>', "Makefile.PL");
    close($fh);
    is Catalyst::Utils::home('MyApp'), dir($d)->absolute->cleanup, "Did find inc '$inc'";
}

{
    my $d = tempdir(CLEANUP => 1);
    local $INC{'MyApp.pm'} = File::Spec->catdir($d, 'MyApp.pm');
    ok !Catalyst::Utils::home('MyApp'), 'No files found';
    mkdir File::Spec->catdir($d, 'MyApp');
    is Catalyst::Utils::home('MyApp'), dir($d, 'MyApp')->absolute->cleanup;
}

{
    my $d = tempdir(CLEANUP => 1);
    chdir($d);
    ok !Catalyst::Utils::find_home_unloaded_in_checkout();
    open(my $fh, '>', "Makefile.PL");
    close($fh);
    is Catalyst::Utils::find_home_unloaded_in_checkout(), cwd(), "Did find home_unloaded_in_checkout"
}

chdir($cwd);

done_testing;

