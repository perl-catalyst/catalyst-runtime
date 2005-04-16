package Catalyst::Utils;

use strict;
use attributes ();

=head1 NAME

Catalyst::Utils - The Catalyst Utils

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item attrs($coderef)

Returns attributes for coderef in a arrayref

=cut

sub attrs { attributes::get( $_[0] ) || [] }

=item prefix($class, $name);

Returns a prefixed action.

=cut

sub prefix {
    my ( $class, $name ) = @_;
    my $prefix = &class2prefix($class);
    $name = "$prefix/$name" if $prefix;
    return $name;
}

=item class2prefix($class);

Returns the prefix for class.

=cut

sub class2prefix {
    my $class = shift || '';
    my $prefix;
    if ( $class =~ /^.*::([MVC]|Model|View|Controller)?::(.*)$/ ) {
        $prefix = lc $2;
        $prefix =~ s/\:\:/\//g;
    }
    return $prefix;
}

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
