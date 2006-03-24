package Catalyst::Plugin::Static::Simple;

use strict;
use warnings;
use base qw/Class::Accessor::Fast Class::Data::Inheritable/;
use File::stat;
use File::Spec::Functions qw/catdir no_upwards splitdir/;
use IO::File;
use MIME::Types;
use NEXT;

our $VERSION = '0.14';

__PACKAGE__->mk_classdata( qw/_static_mime_types/ );
__PACKAGE__->mk_accessors( qw/_static_file
                              _static_debug_message/ );

sub prepare_action {
    my $c = shift;
    my $path = $c->req->path;
    
    $path =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

    # is the URI in a static-defined path?
    foreach my $dir ( @{ $c->config->{static}->{dirs} } ) {
        my $re = ( $dir =~ /^qr\//xms ) ? eval $dir : qr/^${dir}/;
        if ($@) {
            $c->error( "Error compiling static dir regex '$dir': $@" );
        }
        if ( $path =~ $re ) {
            if ( $c->_locate_static_file( $path ) ) {
                $c->_debug_msg( 'from static directory' )
                    if ( $c->config->{static}->{debug} );
            } else {
                $c->_debug_msg( "404: file not found: $path" )
                    if ( $c->config->{static}->{debug} );
                $c->res->status( 404 );
            }
        }
    }
    
    # Does the path have an extension?
    if ( $path =~ /.*\.(\S{1,})$/xms ) {
        # and does it exist?
        $c->_locate_static_file( $path );
    }
    
    return $c->NEXT::ACTUAL::prepare_action(@_);
}

sub dispatch {
    my $c = shift;
    
    return if ( $c->res->status != 200 );
    
    if ( $c->_static_file ) {
        if ( $c->config->{static}->{no_logs} && $c->log->can('abort') ) {
           $c->log->abort( 1 );
        }
        return $c->_serve_static;
    }
    else {
        return $c->NEXT::ACTUAL::dispatch(@_);
    }
}

sub finalize {
    my $c = shift;
    
    # display all log messages
    if ( $c->config->{static}->{debug} && scalar @{$c->_debug_msg} ) {
        $c->log->debug( 'Static::Simple: ' . join q{ }, @{$c->_debug_msg} );
    }
    
    if ( $c->res->status =~ /^(1\d\d|[23]04)$/xms ) {
        $c->res->headers->remove_content_headers;
        return $c->finalize_headers;
    }
    
    return $c->NEXT::ACTUAL::finalize(@_);
}

sub setup {
    my $c = shift;
    
    $c->NEXT::setup(@_);
    
    if ( Catalyst->VERSION le '5.33' ) {
        require File::Slurp;
    }
    
    $c->config->{static}->{dirs} ||= [];
    $c->config->{static}->{include_path} ||= [ $c->config->{root} ];
    $c->config->{static}->{mime_types} ||= {};
    $c->config->{static}->{ignore_extensions} 
        ||= [ qw/tmpl tt tt2 html xhtml/ ];
    $c->config->{static}->{ignore_dirs} ||= [];
    $c->config->{static}->{debug} ||= $c->debug;
    if ( ! defined $c->config->{static}->{no_logs} ) {
        $c->config->{static}->{no_logs} = 1;
    }    
    
    # load up a MIME::Types object, only loading types with
    # at least 1 file extension
    $c->_static_mime_types( MIME::Types->new( only_complete => 1 ) );
    
    # preload the type index hash so it's not built on the first request
    $c->_static_mime_types->create_type_index;
}

# Search through all included directories for the static file
# Based on Template Toolkit INCLUDE_PATH code
sub _locate_static_file {
    my ( $c, $path ) = @_;
    
    $path = catdir( no_upwards( splitdir( $path ) ) );
    
    my @ipaths = @{ $c->config->{static}->{include_path} };
    my $dpaths;
    my $count = 64; # maximum number of directories to search
    
    DIR_CHECK:
    while ( @ipaths && --$count) {
        my $dir = shift @ipaths || next DIR_CHECK;
        
        if ( ref $dir eq 'CODE' ) {
            eval { $dpaths = &$dir( $c ) };
            if ($@) {
                $c->log->error( 'Static::Simple: include_path error: ' . $@ );
            } else {
                unshift @ipaths, @$dpaths;
                next DIR_CHECK;
            }
        } else {
            $dir =~ s/(\/|\\)$//xms;
            if ( -d $dir && -f $dir . '/' . $path ) {
                
                # do we need to ignore the file?
                for my $ignore ( @{ $c->config->{static}->{ignore_dirs} } ) {
                    $ignore =~ s{(/|\\)$}{};
                    if ( $path =~ /^$ignore(\/|\\)/ ) {
                        $c->_debug_msg( "Ignoring directory `$ignore`" )
                            if ( $c->config->{static}->{debug} );
                        next DIR_CHECK;
                    }
                }
                
                # do we need to ignore based on extension?
                for my $ignore_ext 
                    ( @{ $c->config->{static}->{ignore_extensions} } ) {
                        if ( $path =~ /.*\.${ignore_ext}$/ixms ) {
                            $c->_debug_msg( "Ignoring extension `$ignore_ext`" )
                                if ( $c->config->{static}->{debug} );
                            next DIR_CHECK;
                        }
                }
                
                $c->_debug_msg( 'Serving ' . $dir . '/' . $path )
                    if ( $c->config->{static}->{debug} );
                return $c->_static_file( $dir . '/' . $path );
            }
        }
    }
    
    return;
}

sub _serve_static {
    my $c = shift;
           
    my $full_path = $c->_static_file;
    my $type      = $c->_ext_to_type( $full_path );
    my $stat      = stat $full_path;

    $c->res->headers->content_type( $type );
    $c->res->headers->content_length( $stat->size );
    $c->res->headers->last_modified( $stat->mtime );

    if ( Catalyst->VERSION le '5.33' ) {
        # old File::Slurp method
        my $content = File::Slurp::read_file( $full_path );
        $c->res->body( $content );
    }
    else {
        # new method, pass an IO::File object to body
        my $fh = IO::File->new( $full_path, 'r' );
        if ( defined $fh ) {
            binmode $fh;
            $c->res->body( $fh );
        }
        else {
            Catalyst::Exception->throw( 
                message => "Unable to open $full_path for reading" );
        }
    }
    
    return 1;
}

# looks up the correct MIME type for the current file extension
sub _ext_to_type {
    my ( $c, $full_path ) = @_;
    
    if ( $full_path =~ /.*\.(\S{1,})$/xms ) {
        my $ext = $1;
        my $user_types = $c->config->{static}->{mime_types};
        my $type = $user_types->{$ext} 
                || $c->_static_mime_types->mimeTypeOf( $ext );
        if ( $type ) {
            $c->_debug_msg( "as $type" )
                if ( $c->config->{static}->{debug} );            
            return ( ref $type ) ? $type->type : $type;
        }
        else {
            $c->_debug_msg( "as text/plain (unknown extension $ext)" )
                if ( $c->config->{static}->{debug} );
            return 'text/plain';
        }
    }
    else {
        $c->_debug_msg( 'as text/plain (no extension)' )
            if ( $c->config->{static}->{debug} );
        return 'text/plain';
    }
}

sub _debug_msg {
    my ( $c, $msg ) = @_;
    
    if ( !defined $c->_static_debug_message ) {
        $c->_static_debug_message( [] );
    }
    
    if ( $msg ) {
        push @{ $c->_static_debug_message }, $msg;
    }
    
    return $c->_static_debug_message;
}

1;
__END__

=head1 NAME

Catalyst::Plugin::Static::Simple - Make serving static pages painless.

=head1 SYNOPSIS

    use Catalyst;
    MyApp->setup( qw/Static::Simple/ );
    # that's it; static content is automatically served by
    # Catalyst, though you can configure things or bypass
    # Catalyst entirely in a production environment

=head1 DESCRIPTION

The Static::Simple plugin is designed to make serving static content in
your application during development quick and easy, without requiring a
single line of code from you.

This plugin detects static files by looking at the file extension in the
URL (such as B<.css> or B<.png> or B<.js>). The plugin uses the
lightweight L<MIME::Types> module to map file extensions to
IANA-registered MIME types, and will serve your static files with the
correct MIME type directly to the browser, without being processed
through Catalyst.

Note that actions mapped to paths using periods (.) will still operate
properly.

Though Static::Simple is designed to work out-of-the-box, you can tweak
the operation by adding various configuration options. In a production
environment, you will probably want to use your webserver to deliver
static content; for an example see L<USING WITH APACHE>, below.

=head1 DEFAULT BEHAVIOR

By default, Static::Simple will deliver all files having extensions
(that is, bits of text following a period (C<.>)), I<except> files
having the extensions C<tmpl>, C<tt>, C<tt2>, C<html>, and
C<xhtml>. These files, and all files without extensions, will be
processed through Catalyst. If L<MIME::Types> doesn't recognize an
extension, it will be served as C<text/plain>.

To restate: files having the extensions C<tmpl>, C<tt>, C<tt2>, C<html>,
and C<xhtml> I<will not> be served statically by default, they will be
processed by Catalyst. Thus if you want to use C<.html> files from
within a Catalyst app as static files, you need to change the
configuration of Static::Simple. Note also that files having any other
extension I<will> be served statically, so if you're using any other
extension for template files, you should also change the configuration.

Logging of static files is turned off by default.

=head1 ADVANCED CONFIGURATION

Configuration is completely optional and is specified within
C<MyApp-E<gt>config-E<gt>{static}>.  If you use any of these options,
this module will probably feel less "simple" to you!

=head2 Enabling request logging

Since Catalyst 5.50, logging of static requests is turned off by
default; static requests tend to clutter the log output and rarely
reveal anything useful. However, if you want to enable logging of static
requests, you can do so by setting
C<MyApp-E<gt>config-E<gt>{static}-E<gt>{no_logs}> to 0.

=head2 Forcing directories into static mode

Define a list of top-level directories beneath your 'root' directory
that should always be served in static mode.  Regular expressions may be
specified using C<qr//>.

    MyApp->config->{static}->{dirs} = [
        'static',
        qr/^(images|css)/,
    ];

=head2 Including additional directories

You may specify a list of directories in which to search for your static
files. The directories will be searched in order and will return the
first file found. Note that your root directory is B<not> automatically
added to the search path when you specify an C<include_path>. You should
use C<MyApp-E<gt>config-E<gt>{root}> to add it.

    MyApp->config->{static}->{include_path} = [
        '/path/to/overlay',
        \&incpath_generator,
        MyApp->config->{root}
    ];
    
With the above setting, a request for the file C</images/logo.jpg> will search
for the following files, returning the first one found:

    /path/to/overlay/images/logo.jpg
    /dynamic/path/images/logo.jpg
    /your/app/home/root/images/logo.jpg
    
The include path can contain a subroutine reference to dynamically return a
list of available directories.  This method will receive the C<$c> object as a
parameter and should return a reference to a list of directories.  Errors can
be reported using C<die()>.  This method will be called every time a file is
requested that appears to be a static file (i.e. it has an extension).

For example:

    sub incpath_generator {
        my $c = shift;
        
        if ( $c->session->{customer_dir} ) {
            return [ $c->session->{customer_dir} ];
        } else {
            die "No customer dir defined.";
        }
    }
    
=head2 Ignoring certain types of files

There are some file types you may not wish to serve as static files.
Most important in this category are your raw template files.  By
default, files with the extensions C<tmpl>, C<tt>, C<tt2>, C<html>, and
C<xhtml> will be ignored by Static::Simple in the interest of security.
If you wish to define your own extensions to ignore, use the
C<ignore_extensions> option:

    MyApp->config->{static}->{ignore_extensions} 
        = [ qw/html asp php/ ];
    
=head2 Ignoring entire directories

To prevent an entire directory from being served statically, you can use
the C<ignore_dirs> option.  This option contains a list of relative
directory paths to ignore.  If using C<include_path>, the path will be
checked against every included path.

    MyApp->config->{static}->{ignore_dirs} = [ qw/tmpl css/ ];
    
For example, if combined with the above C<include_path> setting, this
C<ignore_dirs> value will ignore the following directories if they exist:

    /path/to/overlay/tmpl
    /path/to/overlay/css
    /dynamic/path/tmpl
    /dynamic/path/css
    /your/app/home/root/tmpl
    /your/app/home/root/css    

=head2 Custom MIME types

To override or add to the default MIME types set by the L<MIME::Types>
module, you may enter your own extension to MIME type mapping.

    MyApp->config->{static}->{mime_types} = {
        jpg => 'image/jpg',
        png => 'image/png',
    };

=head2 Compatibility with other plugins

Since version 0.12, Static::Simple plays nice with other plugins.  It no
longer short-circuits the C<prepare_action> stage as it was causing too
many compatibility issues with other plugins.

=head2 Debugging information

Enable additional debugging information printed in the Catalyst log.  This
is automatically enabled when running Catalyst in -Debug mode.

    MyApp->config->{static}->{debug} = 1;
    
=head1 USING WITH APACHE

While Static::Simple will work just fine serving files through Catalyst in
mod_perl, for increased performance, you may wish to have Apache handle the
serving of your static files.  To do this, simply use a dedicated directory
for your static files and configure an Apache Location block for that
directory.  This approach is recommended for production installations.

    <Location /static>
        SetHandler default-handler
    </Location>

Using this approach Apache will bypass any handling of these directories
through Catalyst. You can leave Static::Simple as part of your
application, and it will continue to function on a development server,
or using Catalyst's built-in server.

=head1 INTERNAL EXTENDED METHODS

Static::Simple extends the following steps in the Catalyst process.

=head2 prepare_action 

C<prepare_action> is used to first check if the request path is a static
file.  If so, we skip all other C<prepare_action> steps to improve
performance.

=head2 dispatch

C<dispatch> takes the file found during C<prepare_action> and writes it
to the output.

=head2 finalize

C<finalize> serves up final header information and displays any log
messages.

=head2 setup

C<setup> initializes all default values.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Plugin::Static>, 
L<http://www.iana.org/assignments/media-types/>

=head1 AUTHOR

Andy Grundman, <andy@hybridized.org>

=head1 CONTRIBUTORS

Marcus Ramberg, <mramberg@cpan.org>
Jesse Sheidlower, <jester@panix.com>

=head1 THANKS

The authors of Catalyst::Plugin::Static:

    Sebastian Riedel
    Christian Hansen
    Marcus Ramberg

For the include_path code from Template Toolkit:

    Andy Wardley

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
