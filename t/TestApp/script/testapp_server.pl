#!/usr/bin/env perl

use FindBin qw/$Bin/;
BEGIN { 
    $ENV{CATALYST_ENGINE} ||= 'HTTP';
    $ENV{CATALYST_SCRIPT_GEN} = 31;
    require Catalyst::Engine::HTTP;
} 

## because this is a test
use lib "$Bin/../../../lib";
use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('Catalyst','Server');


=head1 NAME

testapp_server.pl - Catalyst Testserver

=head1 SYNOPSIS

testapp_server.pl [options]

 Options:
   -d -debug          force debug mode
   -f -fork           handle each request in a new process
                      (defaults to false)
   -? -help           display this help and exits
      -host           host (defaults to all)
   -p -port           port (defaults to 3000)
   -k -keepalive      enable keep-alive connections
   -r -restart        restart when files get modified
                      (defaults to false)
   -rd -restartdelay  delay between file checks
                      (ignored if you have Linux::Inotify2 installed)
   -rr -restartregex  regex match files that trigger
                      a restart when modified
                      (defaults to '\.yml$|\.yaml$|\.conf|\.pm$')
   -restartdirectory  the directory to search for
                      modified files, can be set mulitple times
                      (defaults to '[SCRIPT_DIR]/..')
   -follow_symlinks   follow symlinks in search directories
                      (defaults to false. this is a no-op on Win32)
   -background        run the process in the background
   -pidfile           specify filename for pid file

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst Testserver for this application.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
