package Catalyst::Engine::FastCGI;

use Moose;
extends 'Catalyst::Engine::CGI';

# eval { Class::MOP::load_class("FCGI") };
eval "use FCGI";
die "Unable to load the FCGI module, you may need to install it:\n$@\n" if $@;

=head1 NAME

Catalyst::Engine::FastCGI - FastCGI Engine

=head1 DESCRIPTION

This is the FastCGI engine.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::CGI>.

=head2 $self->run($c, $listen, { option => value, ... })

Starts the FastCGI server.  If C<$listen> is set, then it specifies a
location to listen for FastCGI requests;

=over 4

=item /path

listen via Unix sockets on /path

=item :port

listen via TCP on port on all interfaces

=item hostname:port

listen via TCP on port bound to hostname

=back

Options may also be specified;

=over 4

=item leave_umask

Set to 1 to disable setting umask to 0 for socket open

=item nointr

Do not allow the listener to be interrupted by Ctrl+C

=item nproc

Specify a number of processes for FCGI::ProcManager

=item pidfile

Specify a filename for the pid file

=item manager

Specify a FCGI::ProcManager sub-class

=item detach

Detach from console

=item keep_stderr

Send STDERR to STDOUT instead of the webserver

=back

=cut

sub run {
    my ( $self, $class, $listen, $options ) = @_;

    my $sock = 0;
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
    my $error = \*STDERR; # send STDERR to the web server
       $error = \*STDOUT  # send STDERR to stdout (a logfile)
         if $options->{keep_stderr}; # (if asked to)

    my $request =
      FCGI::Request( \*STDIN, \*STDOUT, $error, \%env, $sock,
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

            # Give each child its own RNG state.
            srand;
        }
        elsif ( $options->{detach} ) {
            $self->daemon_detach();
        }
    }

    while ( $request->Accept >= 0 ) {
        $proc_manager && $proc_manager->pm_pre_dispatch();

        $self->_fix_env( \%env );

        $class->handle_request( env => \%env );

        $proc_manager && $proc_manager->pm_post_dispatch();
    }
}

=head2 $self->write($c, $buffer)

=cut

sub write {
    my ( $self, $c, $buffer ) = @_;

    unless ( $self->_prepared_write ) {
        $self->prepare_write($c);
        $self->_prepared_write(1);
    }

    # XXX: We can't use Engine's write() method because syswrite
    # appears to return bogus values instead of the number of bytes
    # written: http://www.fastcgi.com/om_archive/mail-archive/0128.html

    # Prepend the headers if they have not yet been sent
    if ( $self->_has_header_buf ) {
        $buffer = $self->_clear_header_buf . $buffer;
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

=head2 $self->_fix_env( $env )

Adjusts the environment variables when necessary.

=cut

sub _fix_env
{
    my $self = shift;
    my $env = shift;

    # we are gonna add variables from current system environment %ENV to %env
    # that contains at this moment just variables taken from FastCGI request
    foreach my $k (keys(%ENV)) {
      $env->{$k} = $ENV{$k} unless defined($env->{$k});
    }

    return unless ( $env->{SERVER_SOFTWARE} );

    # If we're running under Lighttpd, swap PATH_INFO and SCRIPT_NAME
    # http://lists.scsys.co.uk/pipermail/catalyst/2006-June/008361.html
    # Thanks to Mark Blythe for this fix
    if ( $env->{SERVER_SOFTWARE} =~ /lighttpd/ ) {
        $env->{PATH_INFO} ||= delete $env->{SCRIPT_NAME};
    }
    elsif ( $env->{SERVER_SOFTWARE} =~ /^nginx/ ) {
        my $script_name = $env->{SCRIPT_NAME};
        $env->{PATH_INFO} =~ s/^$script_name//g;
    }
    # Fix the environment variables PATH_INFO and SCRIPT_NAME when running 
    # under IIS
    elsif ( $env->{SERVER_SOFTWARE} =~ /IIS\/[6-9]\.[0-9]/ ) {
        my @script_name = split(m!/!, $env->{PATH_INFO});
        my @path_translated = split(m!/|\\\\?!, $env->{PATH_TRANSLATED});
        my @path_info;

        while ($script_name[$#script_name] eq $path_translated[$#path_translated]) {
            pop(@path_translated);
            unshift(@path_info, pop(@script_name));
        }

        unshift(@path_info, '', '');

        $env->{PATH_INFO} = join('/', @path_info);
        $env->{SCRIPT_NAME} = join('/', @script_name);
    }
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

    FastCgiExternalServer /tmp/myapp.fcgi -socket /tmp/myapp.socket
    Alias /myapp/ /tmp/myapp.fcgi/

    # Or, run at the root
    Alias / /tmp/myapp.fcgi/

    # Optionally, rewrite the path when accessed without a trailing slash
    RewriteRule ^/myapp$ myapp/ [R]


The FastCgiExternalServer directive tells Apache that when serving
/tmp/myapp to use the FastCGI application listenting on the socket
/tmp/mapp.socket.  Note that /tmp/myapp.fcgi B<MUST NOT> exist --
it's a virtual file name.  With some versions of C<mod_fastcgi> or
C<mod_fcgid>, you can use any name you like, but some require that the
virtual filename end in C<.fcgi>.

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

=head3 Authorization header with mod_fastcgi or mod_cgi

By default, mod_fastcgi/mod_cgi do not pass along the Authorization header,
so modules like C<Catalyst::Plugin::Authentication::Credential::HTTP> will
not work.  To enable pass-through of this header, add the following
mod_rewrite directives:

    RewriteCond %{HTTP:Authorization} ^(.+)
    RewriteRule ^(.*)$ $1 [E=HTTP_AUTHORIZATION:%1,PT]

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
above modes.  Note the required mod_rewrite rule.

    url.rewrite = ( "myapp\$" => "myapp/" )
    fastcgi.server = (
        "/myapp" => (
            "MyApp" => (
                # same as above
            )
        )
    )

For more information on using FastCGI under Lighttpd, visit
L<http://www.lighttpd.net/documentation/fastcgi.html>

=head2 nginx

Catalyst runs under nginx via FastCGI in a similar fashion as the lighttpd
standalone server as described above.

nginx does not have its own internal FastCGI process manager, so you must run
the FastCGI service separately.

=head3 Configuration

To configure nginx, you must configure the FastCGI parameters and also the
socket your FastCGI daemon is listening on.  It can be either a TCP socket
or a Unix file socket.

The server configuration block should look roughly like:

    server {
        listen $port;

        location / {
            fastcgi_param  QUERY_STRING       $query_string;
            fastcgi_param  REQUEST_METHOD     $request_method;
            fastcgi_param  CONTENT_TYPE       $content_type;
            fastcgi_param  CONTENT_LENGTH     $content_length;

            fastcgi_param  SCRIPT_NAME        /;
            fastcgi_param  PATH_INFO          $fastcgi_script_name;
            fastcgi_param  REQUEST_URI        $request_uri;
            fastcgi_param  DOCUMENT_URI       $document_uri;
            fastcgi_param  DOCUMENT_ROOT      $document_root;
            fastcgi_param  SERVER_PROTOCOL    $server_protocol;

            fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
            fastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;

            fastcgi_param  REMOTE_ADDR        $remote_addr;
            fastcgi_param  REMOTE_PORT        $remote_port;
            fastcgi_param  SERVER_ADDR        $server_addr;
            fastcgi_param  SERVER_PORT        $server_port;
            fastcgi_param  SERVER_NAME        $server_name;
        
            # Adjust the socket for your applications!
            fastcgi_pass   unix:$docroot/myapp.socket;
        }
    }

It is the standard convention of nginx to include the fastcgi_params in a
separate file (usually something like C</etc/nginx/fastcgi_params>) and
simply include that file.

=head3  Non-root configuration

If you properly specify the PATH_INFO and SCRIPT_NAME parameters your
application will be accessible at any path. The SCRIPT_NAME variable is the
prefix of your application, and PATH_INFO would be everything in addition.

As an example, if your application is rooted at /myapp, you would configure:

    fastcgi_param  SCRIPT_NAME /myapp/;
    fastcgi_param  PATH_INFO   $fastcgi_script_name;

C<$fastcgi_script_name> would be "/myapp/path/of/the/action".  Catalyst will
process this accordingly and setup the application base as expected.

This behavior is somewhat different than Apache and Lighttpd, but is still
functional.

For more information on nginx, visit:
L<http://nginx.net>

=head2 Microsoft IIS

It is possible to run Catalyst under IIS with FastCGI, but only on IIS 6.0
(Microsoft Windows 2003), IIS 7.0 (Microsoft Windows 2008 and Vista) and
hopefully its successors.

Even if it is declared that FastCGI is supported on IIS 5.1 (Windows XP) it
does not support some features (specifically: wildcard mappings) that prevents
running Catalyst application.

Let us assume that our server has the following layout:

    d:\WWW\WebApp\                   path to our Catalyst application
    d:\strawberry\perl\bin\perl.exe  path to perl interpreter (with Catalyst installed)
    c:\windows                       Windows directory

=head3 Setup IIS 6.0 (Windows 2003)

=over 4

=item Install FastCGI extension for IIS 6.0

FastCGI is not a standard part of IIS 6 - you have to install it separately. For
more info and download go to L<http://www.iis.net/extensions/FastCGI>. Choose
approptiate version (32-bit/64-bit), installation is quite simple
(in fact no questions, no options).

=item Create a new website

Open "Control Panel" > "Administrative Tools" > "Internet Information Services Manager".
Click "Action" > "New" > "Web Site". After you finish the installation wizard
you need to go to the new website's properties.

=item Set website properties

On tab "Web site" set proper values for:
Site Description, IP Address, TCP Port, SSL Port etc.

On tab "Home Directory" set the following:

    Local path: "d:\WWW\WebApp\root"
    Local path permission flags: check only "Read" + "Log visits"
    Execute permitions: "Scripts only"

Click "Configuration" button (still on Home Directory tab) then click "Insert"
the wildcard application mapping and in the next dialog set:

    Executable: "c:\windows\system32\inetsrv\fcgiext.dll"
    Uncheck: "Verify that file exists"

Close all dialogs with "OK".

=item Edit fcgiext.ini

Put the following lines into c:\windows\system32\inetsrv\fcgiext.ini (on 64-bit
system c:\windows\syswow64\inetsrv\fcgiext.ini):

    [Types]
    *:8=CatalystApp
    ;replace 8 with the identification number of the newly created website
    ;it is not so easy to get this number:
    ; - you can use utility "c:\inetpub\adminscripts\adsutil.vbs"
    ;   to list websites:   "cscript adsutil.vbs ENUM /P /W3SVC"
    ;   to get site name:   "cscript adsutil.vbs GET /W3SVC/<number>/ServerComment"
    ;   to get all details: "cscript adsutil.vbs GET /W3SVC/<number>"
    ; - or look where are the logs located:
    ;   c:\WINDOWS\SYSTEM32\Logfiles\W3SVC7\whatever.log
    ;   means that the corresponding number is "7"
    ;if you are running just one website using FastCGI you can use '*=CatalystApp'

    [CatalystApp]
    ExePath=d:\strawberry\perl\bin\perl.exe
    Arguments="d:\WWW\WebApp\script\webapp_fastcgi.pl -e"

    ;by setting this you can instruct IIS to serve Catalyst static files
    ;directly not via FastCGI (in case of any problems try 1)
    IgnoreExistingFiles=0

    ;do not be fooled by Microsoft doc talking about "IgnoreExistingDirectories"
    ;that does not work and use "IgnoreDirectories" instead
    IgnoreDirectories=1

=back

=head3 Setup IIS 7.0 (Windows 2008 and Vista)

Microsoft IIS 7.0 has built-in support for FastCGI so you do not have to install
any addons.

=over 4

=item Necessary steps during IIS7 installation

During IIS7 installation after you have added role "Web Server (IIS)"
you need to check to install role feature "CGI" (do not be nervous that it is
not FastCGI). If you already have IIS7 installed you can add "CGI" role feature
through "Control panel" > "Programs and Features".

=item Create a new website

Open "Control Panel" > "Administrative Tools" > "Internet Information Services Manager"
> "Add Web Site".

    site name: "CatalystSite"
    content directory: "d:\WWW\WebApp\root"
    binding: set proper IP address, port etc.

=item Configure FastCGI

You can configure FastCGI extension using commandline utility
"c:\windows\system32\inetsrv\appcmd.exe"

=over 4

=item Configuring section "fastCgi" (it is a global setting)

  appcmd.exe set config -section:system.webServer/fastCgi /+"[fullPath='d:\strawberry\perl\bin\perl.exe',arguments='d:\www\WebApp\script\webapp_fastcgi.pl -e',maxInstances='4',idleTimeout='300',activityTimeout='30',requestTimeout='90',instanceMaxRequests='1000',protocol='NamedPipe',flushNamedPipe='False']" /commit:apphost

=item Configuring proper handler (it is a site related setting)

  appcmd.exe set config "CatalystSite" -section:system.webServer/handlers /+"[name='CatalystFastCGI',path='*',verb='GET,HEAD,POST',modules='FastCgiModule',scriptProcessor='d:\strawberry\perl\bin\perl.exe|d:\www\WebApp\script\webapp_fastcgi.pl -e',resourceType='Unspecified',requireAccess='Script']" /commit:apphost

Note: before launching the commands above do not forget to change site
name and paths to values relevant for your server setup.

=back

=back

=head1 SEE ALSO

L<Catalyst>, L<FCGI>.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 THANKS

Bill Moseley, for documentation updates and testing.

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
