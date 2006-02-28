package Catalyst::Plugin::ConfigLoader::YAML;

use strict;
use warnings;

=head1 NAME

Catalyst::Plugin::ConfigLoader::YAML - Load YAML config files

=head1 DESCRIPTION

Loads YAML files. Example:

    ---
    name: TestApp
    Controller::Foo:
        foo: bar

=head1 METHODS

=head2 extensions( )

return an array of valid extensions (C<yml>, C<yaml>).

=cut

sub extensions {
    return qw( yml yaml );
}

=head2 load( $file )

Attempts to load C<$file> as a YAML file.

=cut

sub load {
    my $class = shift;
    my $file  = shift;

    eval { require YAML::Syck; };
    if( $@ ) {
        require YAML;
        return YAML::LoadFile( $file );
    }
    else {
        open( my $fh, $file ) or die $!;
        my $content = do { local $/; <$fh> };
        close $fh;
        return YAML::Syck::Load( $content );
    }
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

=item * L<Catalyst::Plugin::ConfigLoader>

=back

=cut

1;