package Catalyst::Request::Upload;

use strict;
use base 'Class::Accessor::Fast';

use Catalyst::Exception;
use File::Copy ();
use IO::File   ();

__PACKAGE__->mk_accessors(qw/filename headers size tempname type/);

sub new { shift->SUPER::new( ref( $_[0] ) ? $_[0] : {@_} ) }

=head1 NAME

Catalyst::Request::Upload - Catalyst Request Upload Class

=head1 SYNOPSIS

    $upload->copy_to
    $upload->fh
    $upload->filename;
    $upload->headers;
    $upload->link_to;
    $upload->size;
    $upload->slurp;
    $upload->tempname;
    $upload->type;

See also L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst Request Upload class, which provides a set of accessors 
to the upload data.

=head1 METHODS

=over 4

=item $upload->new

simple constructor.

=item $upload->copy_to

Copies tempname using C<File::Copy>. Returns true for success, false otherwise.

     $upload->copy_to('/path/to/target');

=cut

sub copy_to {
    my $self = shift;
    return File::Copy::copy( $self->tempname, @_ );
}

=item $upload->fh

Opens tempname and returns a C<IO::File> handle.

=cut

sub fh {
    my $self = shift;

    my $fh = IO::File->new( $self->tempname, IO::File::O_RDONLY );

    unless ( defined $fh ) {

        my $filename = $self->tempname;

        Catalyst::Exception->throw(
            message => qq/Can't open '$filename': '$!'/ );
    }

    return $fh;
}

=item $upload->filename

Contains client supplied filename.

=item $upload->headers

Returns a C<HTTP::Headers> object.

=item $upload->link_to

Creates a hard link to the tempname.  Returns true for success, 
false otherwise.

    $upload->link_to('/path/to/target');

=cut

sub link_to {
    my ( $self, $target ) = @_;
    return CORE::link( $self->tempname, $target );
}

=item $upload->size

Contains size of the file in bytes.

=item $upload->slurp

Returns a scalar containing contents of tempname.

=cut

sub slurp {
    my ( $self, $layer ) = @_;

    unless ($layer) {
        $layer = ':raw';
    }

    my $content = undef;
    my $handle  = $self->fh;

    binmode( $handle, $layer );

    while ( $handle->sysread( my $buffer, 8192 ) ) {
        $content .= $buffer;
    }

    return $content;
}

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
