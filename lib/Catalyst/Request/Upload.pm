package Catalyst::Request::Upload;

use strict;
use base 'Class::Accessor::Fast';

use File::Copy ();
use IO::File   ();

__PACKAGE__->mk_accessors(qw/filename size tempname type/);

sub new { shift->SUPER::new( ref( $_[0] ) ? $_[0] : {@_} ) }

=head1 NAME

Catalyst::Request::Upload - Catalyst Request Upload Class

=head1 SYNOPSIS

    $upload->copy
    $upload->fh
    $upload->filename;
    $upload->link;
    $upload->size;
    $upload->tempname;
    $upload->type;

See also L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst Request Upload class, which provides a set of accessors 
to the upload data.

=head1 METHODS

=over 4

=item $upload->copy( $target [, $bufferlen ] )

Copies tempname using C<File::Copy>. Returns true for success, false otherwise.

=cut

sub copy {
    my ( $self, $target, $buffer ) = @_;
    return File::Copy::copy( $self->tempname, $target, $buffer );
}

=item $upload->fh

Opens tempname and returns a C<IO::File> handle.

=cut

sub fh {
    my $self = shift;

    my $fh = IO::File->new( $self->tempname, IO::File::O_RDONLY )
      or die( "Can't open ", $self->tempname, ": ", $! );

    return $fh;
}

=item $upload->filename

Contains client supplied filename.

=item $upload->link

Creates a new filename linked to the old filename.  Returns true for
success, false otherwise.

    $upload->link('/my/path');

=cut

sub link {
    my ( $self, $target ) = @_;
    return CORE::link( $self->tempname, $target );
}

=item $upload->size

Contains size of the file in bytes.

=item $upload->tempname

Contains path to the temporary spool file.

=item $upload->type

Contains client supplied Content-Type.

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
