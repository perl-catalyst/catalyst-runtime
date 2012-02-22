use strict;
use warnings;
use Test::More;
use FindBin qw/$Bin/;
use Test::Exception;
use lib "$Bin/../lib";
use File::Temp qw/ tempdir /;
use Cwd;

use_ok('Catalyst::ScriptRunner');

my $cwd = cwd();

my $d = tempdir(); #CLEANUP => 1);
chdir($d) or die;
mkdir("lib") or die;
mkdir(File::Spec->catdir("lib", "MyApp")) or die;
mkdir(File::Spec->catdir("lib", "MyApp", "Script")) or die;

open(my $fh, '>', 'Makefile.PL') or die;
close($fh) or die;

open($fh, '>', File::Spec->catdir("lib", "MyApp", "Script", "Foo.pm")) or die;
print $fh q{package MyApp::Script::Foo;
use Moose;
use namespace::autoclean;

with 'Catalyst::ScriptRole';

sub run { __PACKAGE__ }

1;
};
close($fh) or die;

use_ok 'Catalyst::ScriptRunner';

is Catalyst::ScriptRunner->run('MyApp', 'Foo'), 'MyApp::Script::Foo';

chdir($cwd) or die;

done_testing;
