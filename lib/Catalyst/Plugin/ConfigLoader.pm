package Catalyst::Plugin::ConfigLoader;

use strict;
use warnings;

use NEXT;
use Module::Pluggable::Fast
    name    => '_config_loaders',
    search  => [ __PACKAGE__ ],
    require => 1;

our $VERSION = '0.03';

=head1 NAME

Catalyst::Plugin::ConfigLoader - Load config files of various types

=head1 SYNOPSIS

    package MyApp;
    
    # ConfigLoader should be first in your list so
    # other plugins can get the config information
    use Catalyst qw( ConfigLoader ... );
	
    # by default myapp.* will be loaded
    # you can specify a file if you'd like
    __PACKAGE__->config( file = > 'config.yaml' );
    

=head1 DESCRIPTION

This mdoule will attempt to load find and load a configuration
file of various types. Currently it supports YAML, JSON, XML,
INI and Perl formats.

=head1 METHODS

=head2 setup( )

This method is automatically called by Catalyst's setup routine. It will
attempt to use each plugin and, once a file has been successfully
loaded, set the C<config()> section.

=cut

sub setup {
    my $c    = shift;
    my $path = $c->config->{ file } || $c->path_to( Catalyst::Utils::appprefix( ref $c || $c ) );

    my( $extension ) = ( $path =~ /\.(.{1,4})$/ );
    
    for my $loader ( $c->_config_loaders ) {
        my @files;
        my @extensions = $loader->extensions;
        if( $extension ) {
            next unless grep { $_ eq $extension } @extensions;
            push @files, $path;
        }
        else {
            push @files, "$path.$_" for @extensions;
        }

        for( @files ) {
            next unless -f $_;
            my $config = $loader->load( $_ );
            if( $config ) {
                $c->config( $config );
                last;
            }
        }
    }

    $c->NEXT::setup( @_ );
}

=head1 AUTHOR

=over 4 

=item * Brian Cassidy E<lt>bricas@cpan.orgE<gt>

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