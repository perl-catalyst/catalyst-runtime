use strict;
use warnings;
use Test::More;
use FindBin qw/$Bin/;
use IO::Handle;
use Try::Tiny;
use File::Temp qw/ tempfile /;
use lib "$Bin/../lib";

use_ok('Catalyst::ScriptRunner');
use_ok('ScriptTestApp');

is ScriptTestApp->run_options, undef;

my ($fh, $fn) = tempfile();

binmode( $fh );
binmode( STDOUT );

local @ARGV = ();
local %ENV;

my $saved;
open( $saved, '>&'. STDOUT->fileno )
    or croak("Can't dup stdout: $!");
open( STDOUT, '>&='. $fh->fileno )
    or croak("Can't open stdout: $!");
local $SIG{__WARN__} = sub {}; # Shut up warnings...
try { Catalyst::ScriptRunner->run('ScriptTestApp', 'CGI'); pass("Ran ok") }
catch { fail "Failed to run $_" };

STDOUT->flush
    or croak("Can't flush stdout: $!");

open( STDOUT, '>&'. fileno($saved) )
    or croak("Can't restore stdout: $!");

is_deeply ScriptTestApp->run_options, { argv => [], extra_argv => [] };

done_testing;
