package Catalyst::Plugin::ConfigLoader;

use strict;
use warnings;

use NEXT;
use Module::Pluggable::Fast
    name    => '_config_loaders',
    search  => [ __PACKAGE__ ],
    require => 1;
use Data::Visitor::Callback;

our $VERSION = '0.08';

=head1 NAME

Catalyst::Plugin::ConfigLoader - Load config files of various types

=head1 SYNOPSIS

    package MyApp;
    
    # ConfigLoader should be first in your list so
    # other plugins can get the config information
    use Catalyst qw( ConfigLoader ... );
    
    # by default myapp.* will be loaded
    # you can specify a file if you'd like
    __PACKAGE__->config( file => 'config.yaml' );    

=head1 DESCRIPTION

This module will attempt to load find and load a configuration
file of various types. Currently it supports YAML, JSON, XML,
INI and Perl formats.

To support the distinction between development and production environments,
this module will also attemp to load a local config (e.g. myapp_local.yaml)
which will override any duplicate settings.

=head1 METHODS

=head2 setup( )

This method is automatically called by Catalyst's setup routine. It will
attempt to use each plugin and, once a file has been successfully
loaded, set the C<config()> section. 

=cut

sub setup {
    my $c = shift;
    my( $path, $extension ) = $c->get_config_path;
    
    for my $loader ( $c->_config_loaders ) {
        my @files;
        my @extensions = $loader->extensions;
        if( $extension ) {
            next unless grep { $_ eq $extension } @extensions;
            push @files, $path;
        }
        else {
            @files = map { ( "$path.$_", "${path}_local.$_" ) } @extensions;
        }

        for( @files ) {
            next unless -f $_;
            my $config = $loader->load( $_ );

            $c->log->debug( "Loaded Config $_" ) if $c->debug;
            
            next if !$config;

            _fix_syntax( $config );
            
            # merge hashes 1 level down
            for my $key ( keys %$config ) {
                if( exists $c->config->{ $key } ) {
                    my $isa_ref = ref $config->{ $key };

                    next if !$isa_ref or $isa_ref ne 'HASH';

                    my %temp = ( %{ $c->config->{ $key } }, %{ $config->{ $key } } );
                    $config->{ $key } = \%temp;
                }
            }
            
            $c->config( $config );
        }
    }

    $c->finalize_config;

    $c->NEXT::setup( @_ );
}

=head2 finalize_config

This method is called after the config file is loaded. It can be
used to implement tuning of config values that can only be done
at runtime. If you need to do this to properly configure any
plugins, it's important to load ConfigLoader before them.
ConfigLoader provides a default finalize_config method which
walks through the loaded config hash and replaces any strings
beginning containing C<__HOME__> with the full path to
app's home directory (i.e. C<$c-E<gt>path_to('')> ).
You can also use C<__path_to('foo/bar')__> which translates to
C<$c-E<gt>path_to('foo', 'bar')> 

=cut

sub finalize_config {
    my $c = shift;
    my $v = Data::Visitor::Callback->new(
        plain_value => sub {
            return unless defined $_;
            s[__HOME__][ $c->path_to( '' ) ]e;
            s[__path_to\((.+)\)__][ $c->path_to( split( '/', $1 ) ) ]e;
        }
    );
    $v->visit( $c->config );
}

=head2 get_config_path

This method determines the path, filename prefix and file extension to be used
for config loading. It returns the path (up to the filename less the
extension) to check and the specific extension to use (if it was specified).

The order of preference is specified as:

=over 4

=item * C<$ENV{ MYAPP_CONFIG }>

=item * C<$c->config->{ file }>

=item * C<$c->path_to( $application_prefix )>

=back

If either of the first two user-specified options are directories, the
application prefix will be added on to the end of the path.

=cut

sub get_config_path {
    my $c       = shift;
    my $appname = ref $c || $c;
    my $prefix  = Catalyst::Utils::appprefix( $appname );
    my $path    = $ENV{ Catalyst::Utils::class2env( $appname ) . '_CONFIG' }
        || $c->config->{ file }
        || $c->path_to( $prefix );

    my( $extension ) = ( $path =~ /\.(.{1,4})$/ );
    
    if( -d $path ) {
        $path  =~ s/[\/\\]$//;
        $path .= "/$prefix";
    }
    
    return( $path, $extension );
}

sub _fix_syntax {
    my $config     = shift;
    my @components = (
        map +{
            prefix => $_ eq 'Component' ? '' : $_ . '::',
            values => delete $config->{ lc $_ } || delete $config->{ $_ }
        }, qw( Component Model View Controller )
    );

    foreach my $comp ( @components ) {
        my $prefix = $comp->{ prefix };
        foreach my $element ( keys %{ $comp->{ values } } ) {
            $config->{ "$prefix$element" } = $comp->{ values }->{ $element };
        }
    }
}

=head1 AUTHOR

=over 4 

=item * Brian Cassidy E<lt>bricas@cpan.orgE<gt>

=back

=head1 CONTRIBUTORS

The following people have generously donated their time to the
development of this module:

=over 4

=item * David Kamholz E<lt>dkamholz@cpan.orgE<gt>

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Brian Cassidy

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=head1 SEE ALSO

=over 4 

=item * L<Catalyst>

=back

=cut

1;
