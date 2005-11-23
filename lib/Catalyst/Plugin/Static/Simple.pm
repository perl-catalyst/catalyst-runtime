package Catalyst::Plugin::Static::Simple;

use strict;
use warnings;
use base qw/Class::Accessor::Fast Class::Data::Inheritable/;
use File::stat;
use File::Spec::Functions qw/catdir no_upwards splitdir/;
use IO::File;
use MIME::Types;
use NEXT;

our $VERSION = '0.12';

__PACKAGE__->mk_classdata( qw/_static_mime_types/ );
__PACKAGE__->mk_accessors( qw/_static_file
                              _static_debug_message/ );

sub prepare_action {
    my $c = shift;
    my $path = $c->req->path;

    # is the URI in a static-defined path?
    foreach my $dir ( @{ $c->config->{static}->{dirs} } ) {
        my $re = ( $dir =~ /^qr\//xms ) ? eval $dir : qr/^${dir}/;
        if ($@) {
            $c->error( "Error compiling static dir regex '$dir': $@" );
        }
        if ( $path =~ $re ) {
            if ( $c->_locate_static_file ) {
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
        $c->_locate_static_file;
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
    my $c = shift;
    
    my $path = catdir( no_upwards( splitdir( $c->req->path ) ) );
    
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
            $dir =~ s/\/$//xms;
            if ( -d $dir && -f $dir . '/' . $path ) {
                
                # do we need to ignore the file?
                for my $ignore ( @{ $c->config->{static}->{ignore_dirs} } ) {
                    $ignore =~ s{/$}{};
                    if ( $path =~ /^$ignore\// ) {
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
    
    my $path = $c->req->path;    
    my $type = $c->_ext_to_type;
    
    my $full_path = $c->_static_file;
    my $stat = stat $full_path;

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
    my $c = shift;
    my $path = $c->req->path;
    
    if ( $path =~ /.*\.(\S{1,})$/xms ) {
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

=head1 DESCRIPTION

The Static::Simple plugin is designed to make serving static content in your
application during development quick and easy, without requiring a single
line of code from you.

It will detect static files used in your application by looking for file
extensions in the URI.  By default, you can simply load this plugin and it
will immediately begin serving your static files with the correct MIME type.
The light-weight MIME::Types module is used to map file extensions to
IANA-registered MIME types.

Note that actions mapped to paths using periods (.) will still operate
properly.

You may further tweak the operation by adding configuration options, described
below.

=head1 ADVANCED CONFIGURATION

Configuration is completely optional and is specified within 
MyApp->config->{static}.  If you use any of these options, the module will
probably feel less "simple" to you!

=head2 Aborting request logging

Since Catalyst 5.50, there has been added support for dropping logging for a 
request. This is enabled by default for static files, as static requests tend
to clutter the log output.  However, if you want logging of static requests, 
you can enable it by setting MyApp->config->{static}->{no_logs} to 0.

=head2 Forcing directories into static mode

Define a list of top-level directories beneath your 'root' directory that
should always be served in static mode.  Regular expressions may be
specified using qr//.

    MyApp->config->{static}->{dirs} = [
        'static',
        qr/^(images|css)/,
    ];

=head2 Including additional directories

You may specify a list of directories in which to search for your static
files.  The directories will be searched in order and will return the first
file found.  Note that your root directory is B<not> automatically added to
the search path when you specify an include_path.  You should use
MyApp->config->{root} to add it.

    MyApp->config->{static}->{include_path} = [
        '/path/to/overlay',
        \&incpath_generator,
        MyApp->config->{root}
    ];
    
With the above setting, a request for the file /images/logo.jpg will search
for the following files, returning the first one found:

    /path/to/overlay/images/logo.jpg
    /dynamic/path/images/logo.jpg
    /your/app/home/root/images/logo.jpg
    
The include path can contain a subroutine reference to dynamically return a
list of available directories.  This method will receive the $c object as a
parameter and should return a reference to a list of directories.  Errors can
be reported using die().  This method will be called every time a file is
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

There are some file types you may not wish to serve as static files.  Most
important in this category are your raw template files.  By default, files
with the extensions tmpl, tt, tt2, html, and xhtml will be ignored by
Static::Simple in the interest of security.  If you wish to define your own
extensions to ignore, use the ignore_extensions option:

    MyApp->config->{static}->{ignore_extensions} 
        = [ qw/tmpl tt tt2 html xhtml/ ];
    
=head2 Ignoring entire directories

To prevent an entire directory from being served statically, you can use the
ignore_dirs option.  This option contains a list of relative directory paths
to ignore.  If using include_path, the path will be checked against every
included path.

    MyApp->config->{static}->{ignore_dirs} = [ qw/tmpl css/ ];
    
For example, if combined with the above include_path setting, this
ignore_dirs value will ignore the following directories if they exist:

    /path/to/overlay/tmpl
    /path/to/overlay/css
    /dynamic/path/tmpl
    /dynamic/path/css
    /your/app/home/root/tmpl
    /your/app/home/root/css    

=head2 Custom MIME types

To override or add to the default MIME types set by the MIME::Types module,
you may enter your own extension to MIME type mapping. 

    MyApp->config->{static}->{mime_types} = {
        jpg => 'image/jpg',
        png => 'image/png',
    };

=head2 Compatibility with other plugins

Since version 0.12, Static::Simple plays nice with other plugins.  It no
longer short-circuits the prepare_action stage as it was causing too many
compatibility issues with other plugins.

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

=head1 INTERNAL EXTENDED METHODS

Static::Simple extends the following steps in the Catalyst process.

=head2 prepare_action 

prepare_action is used to first check if the request path is a static file.
If so, we skip all other prepare_action steps to improve performance.

=head2 dispatch

dispatch takes the file found during prepare_action and writes it to the
output.

=head2 finalize

finalize serves up final header information and displays any log messages.

=head2 setup

setup initializes all default values.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Plugin::Static>, 
L<http://www.iana.org/assignments/media-types/>

=head1 AUTHOR

Andy Grundman, <andy@hybridized.org>

=head1 CONTRIBUTORS

Marcus Ramberg, <mramberg@cpan.org>

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
