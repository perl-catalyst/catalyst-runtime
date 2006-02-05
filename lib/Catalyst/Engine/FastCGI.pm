package Catalyst::Engine::FastCGI;

use strict;
use base 'Catalyst::Engine::CGI';
eval "use FCGI";
die "Please install FCGI\n" if $@;

=head1 NAME

Catalyst::Engine::FastCGI - FastCGI Engine

=head1 DESCRIPTION

This is the FastCGI engine.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::CGI>.

=head2 $self->run($c, $listen, { option => value, ... })
 
Starts the FastCGI server.  If C<$listen> is set, then it specifies a
location to listen for FastCGI requests;

  Form            Meaning
  /path           listen via Unix sockets on /path
  :port           listen via TCP on port on all interfaces
  hostname:port   listen via TCP on port bound to hostname

Options may also be specified;

  Option          Meaning
  leave_umask     Set to 1 to disable setting umask to 0
                  for socket open
  nointr          Do not allow the listener to be
                  interrupted by Ctrl+C
  nproc           Specify a number of processes for
                  FCGI::ProcManager
  pidfile         Specify a filename for the pid file
  manager         Specify a FCGI::ProcManager sub-class
  detach          Detach from console

=cut

sub run {
    my ( $self, $class, $listen, $options ) = @_;

    my $sock;
    if ($listen) {
        my $old_umask = umask;
        unless ( $options->{leave_umask} ) {
            umask(0);
        }
        $sock = FCGI::OpenSocket( $listen, 100 )
          or die "failed to open FastCGI socket; $!";
        unless ( $options->{leave_umask} ) {
            umask($old_umask);
        }
    }
    elsif ( $^O ne 'MSWin32' ) {
        -S STDIN
          or die "STDIN is not a socket; specify a listen location";
    }

    $options ||= {};

    my %env;

    my $request =
      FCGI::Request( \*STDIN, \*STDOUT, \*STDERR, \%env, $sock,
        ( $options->{nointr} ? 0 : &FCGI::FAIL_ACCEPT_ON_INTR ),
      );

    my $proc_manager;

    if ($listen) {
        $options->{manager} ||= "FCGI::ProcManager";
        $options->{nproc}   ||= 1;

        $self->daemon_fork() if $options->{detach};

        if ( $options->{manager} ) {
            eval "use $options->{manager}; 1" or die $@;

            $proc_manager = $options->{manager}->new(
                {
                    n_processes => $options->{nproc},
                    pid_fname   => $options->{pidfile},
                }
            );

            # detach *before* the ProcManager inits
            $self->daemon_detach() if $options->{detach};

            $proc_manager->pm_manage();
        }
        elsif ( $options->{detach} ) {
            $self->daemon_detach();
        }
    }

    while ( $request->Accept >= 0 ) {
        $proc_manager && $proc_manager->pm_pre_dispatch();
        $class->handle_request( env => \%env );
        $proc_manager && $proc_manager->pm_post_dispatch();
    }
}

=head2 $self->write($c, $buffer)

=cut

sub write {
    my ( $self, $c, $buffer ) = @_;

    unless ( $self->{_prepared_write} ) {
        $self->prepare_write($c);
        $self->{_prepared_write} = 1;
    }

    # FastCGI does not stream data properly if using 'print $handle',
    # but a syswrite appears to work properly.
    *STDOUT->syswrite($buffer);
}

=head2 $self->daemon_fork()

Performs the first part of daemon initialisation.  Specifically,
forking.  STDERR, etc are still connected to a terminal.

=cut

sub daemon_fork {
    require POSIX;
    fork && exit;
}

=head2 $self->daemon_detach( )

Performs the second part of daemon initialisation.  Specifically,
disassociates from the terminal.

However, this does B<not> change the current working directory to "/",
as normal daemons do.  It also does not close all open file
descriptors (except STDIN, STDOUT and STDERR, which are re-opened from
F</dev/null>).

=cut

sub daemon_detach {
    my $self = shift;
    print "FastCGI daemon started (pid $$)\n";
    open STDIN,  "+</dev/null" or die $!;
    open STDOUT, ">&STDIN"     or die $!;
    open STDERR, ">&STDIN"     or die $!;
    POSIX::setsid();
}

1;
__END__

=head1 WEB SERVER CONFIGURATIONS

=head2 Standalone FastCGI Server

In server mode the application runs as a standalone server and accepts 
connections from a web server.  The application can be on the same machine as
the web server, on a remote machine, or even on multiple remote machines.
Advantages of this method include running the Catalyst application as a
different user than the web server, and the ability to set up a scalable
server farm.

To start your application in server mode, install the FCGI::ProcManager
module and then use the included fastcgi.pl script.

    $ script/myapp_fastcgi.pl -l /tmp/myapp.socket -n 5
    
Command line options for fastcgi.pl include:

    -d -daemon     Daemonize the server.
    -p -pidfile    Write a pidfile with the pid of the process manager.
    -l -listen     Listen on a socket path, hostname:port, or :port.
    -n -nproc      The number of processes started to handle requests.
    
See below for the specific web server configurations for using the external
server.

=head2 Apache 1.x, 2.x

Apache requires the mod_fastcgi module.  The same module supports both
Apache 1 and 2.

There are three ways to run your application under FastCGI on Apache: server, 
static, and dynamic.

=head3 Standalone server mode

    FastCgiExternalServer /tmp/myapp -socket /tmp/myapp.socket
    Alias /myapp/ /tmp/myapp/
    
    # Or, run at the root
    Alias / /tmp/myapp/
    
    # Optionally, rewrite the path when accessed without a trailing slash
    RewriteRule ^/myapp$ myapp/ [R]
    
The FastCgiExternalServer directive tells Apache that when serving /tmp/myapp
to use the FastCGI application listenting on the socket /tmp/mapp.socket. 
Note that /tmp/myapp does not need to exist -- it's a virtual file name.

It's likely that Apache is not configured to serve files in /tmp, so the 
Alias directive maps the url path /myapp/ to the (virtual) file that runs the
FastCGI application. The trailing slashes are important as their use will
correctly set the PATH_INFO environment variable used by Catalyst to
determine the request path.  If you would like to be able to access your app
without a trailing slash (http://server/myapp), you can use the above
RewriteRule directive.

=head3 Static mode

The term 'static' is misleading, but in static mode Apache uses its own
FastCGI Process Manager to start the application processes.  This happens at
Apache startup time.  In this case you do not run your application's
fastcgi.pl script -- that is done by Apache. Apache then maps URIs to the
FastCGI script to run your application.

    FastCgiServer /path/to/myapp/script/myapp_fastcgi.pl -processes 3
    Alias /myapp/ /path/to/myapp/script/myapp_fastcgi.pl/
    
FastCgiServer tells Apache to start three processes of your application at
startup.  The Alias command maps a path to the FastCGI application. Again,
the trailing slashes are important.
    
=head3 Dynamic mode

In FastCGI dynamic mode, Apache will run your application on demand, 
typically by requesting a file with a specific extension (e.g. .fcgi).  ISPs
often use this type of setup to provide FastCGI support to many customers.

In this mode it is often enough to place or link your *_fastcgi.pl script in
your cgi-bin directory with the extension of .fcgi.  In dynamic mode Apache
must be able to run your application as a CGI script so ExecCGI must be
enabled for the directory.

    AddHandler fastcgi-script .fcgi

The above tells Apache to run any .fcgi file as a FastCGI application.

Here is a complete example:

    <VirtualHost *:80>
        ServerName www.myapp.com
        DocumentRoot /path/to/MyApp

        # Allow CGI script to run
        <Directory /path/to/MyApp>
            Options +ExecCGI
        </Directory>

        # Tell Apache this is a FastCGI application
        <Files myapp_fastcgi.pl>
            SetHandler fastcgi-script
        </Files>
    </VirtualHost>

Then a request for /script/myapp_fastcgi.pl will run the
application.
    
For more information on using FastCGI under Apache, visit
L<http://www.fastcgi.com/mod_fastcgi/docs/mod_fastcgi.html>

=head2 Lighttpd

These configurations were tested with Lighttpd 1.4.7.

=head3 Standalone server mode

    server.document-root = "/var/www/MyApp/root"

    fastcgi.server = (
        "" => (
            "MyApp" => (
                "socket"      => "/tmp/myapp.socket",
                "check-local" => "disable"
            )
        )
    )

=head3 Static mode

    server.document-root = "/var/www/MyApp/root"
    
    fastcgi.server = (
        "" => (
            "MyApp" => (
                "socket"       => "/tmp/myapp.socket",
                "check-local"  => "disable",
                "bin-path"     => "/var/www/MyApp/script/myapp_fastcgi.pl",
                "min-procs"    => 2,
                "max-procs"    => 5,
                "idle-timeout" => 20
            )
        )
    )
    
Note that in newer versions of lighttpd, the min-procs and idle-timeout
values are disabled.  The above example would start 5 processes.

=head3 Non-root configuration
    
You can also run your application at any non-root location with either of the
above modes.

    fastcgi.server = (
        "/myapp" => (
            "MyApp" => (
                # same as above
            )
        )
    )

For more information on using FastCGI under Lighttpd, visit
L<http://www.lighttpd.net/documentation/fastcgi.html>

=head2 IIS

It is possible to run Catalyst under IIS with FastCGI, but we do not
yet have detailed instructions.

=head1 SEE ALSO

L<Catalyst>, L<FCGI>.

=head1 AUTHORS

Sebastian Riedel, <sri@cpan.org>

Christian Hansen, <ch@ngmedia.com>

Andy Grundman, <andy@hybridized.org>

=head1 THANKS

Bill Moseley, for documentation updates and testing.

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
