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
    else {
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
        $proc_manager && $proc_manager->pm_pre_dispatch();
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

=head2 Apache 1.x, 2.x

Apache requires the mod_fastcgi module.  The following config will let Apache
control the running of your FastCGI processes.

    # Launch the FastCGI processes
    FastCgiIpcDir /tmp
    FastCgiServer /var/www/MyApp/script/myapp_fastcgi.pl -idle-timeout 300 -processes 5
    
    <VirtualHost *>
        ScriptAlias / /var/www/MyApp/script/myapp_fastcgi.pl/
    </VirtualHost>
    
You can also tell Apache to connect to an external FastCGI server:

    # Start the external server (requires FCGI::ProcManager)
    $ script/myapp_fastcgi.pl -l /tmp/myapp.socket -n 5
    
    # Note that the path used in FastCgiExternalServer can be any path
    FastCgiIpcDir /tmp
    FastCgiExternalServer /tmp/myapp_fastcgi.pl -socket /tmp/myapp.socket
    
    <VirtualHost *>
        ScriptAlias / /tmp/myapp_fastcgi.pl/
    </VirtualHost>
    
For more information on using FastCGI under Apache, visit
L<http://www.fastcgi.com/mod_fastcgi/docs/mod_fastcgi.html>

=head2 Lighttpd

This configuration was tested with Lighttpd 1.4.7.

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
    
You can also run your application at any non-root location.

    fastcgi.server = (
        "/myapp" => (
            "MyApp" => (
                # same as above
            )
        )
    )
    
You can also use an external server:

    # Start the external server (requires FCGI::ProcManager)
    $ script/myapp_fastcgi.pl -l /tmp/myapp.socket -n 5

    server.document-root = "/var/www/MyApp/root"

    fastcgi.server = (
        "" => (
            "MyApp" => (
                "socket"      => "/tmp/myapp.socket",
                "check-local" => "disable"
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

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
