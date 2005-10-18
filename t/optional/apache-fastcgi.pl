#!perl

# Run all tests against FastCGI mode under Apache
#
# Note, to get this to run properly, you may need to give it the path to your
# httpd.conf:
# 
# perl t/optional/apache-fastcgi.pl -httpd_conf /etc/apache/httpd.conf

use strict;
use warnings;

use Apache::Test;
use Apache::TestRun ();

use File::Path;
use File::Copy::Recursive;
use FindBin;

# clean up
rmtree "$FindBin::Bin/../../t/var" if -d "$FindBin::Bin/../../t/var";

# create a TestApp and copy the test libs into it
mkdir "$FindBin::Bin/../../t/var";
chdir "$FindBin::Bin/../../t/var";
system "$FindBin::Bin/../../script/catalyst.pl TestApp";
chdir "$FindBin::Bin/../..";
File::Copy::Recursive::dircopy( 't/live/lib', 't/var/TestApp/lib' );

# remove TestApp's tests so Apache::Test doesn't try to run them
rmtree 't/var/TestApp/t';

my $cfg  = Apache::Test::config();
$ENV{CATALYST_SERVER} = 'http://' . $cfg->hostport . '/fastcgi';

Apache::TestRun->new->run(@ARGV);

# clean up
rmtree "$FindBin::Bin/../../t/var" if -d "$FindBin::Bin/../../t/var";
