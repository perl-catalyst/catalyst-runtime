package Catalyst::Request::Upload;

use strict;
use base 'Class::Accessor::Fast';

use Catalyst::Exception;
use File::Copy ();
use IO::File   ();

__PACKAGE__->mk_accessors(qw/filename headers size tempname type/);

sub new { shift->SUPER::new( ref( $_[0] ) ? $_[0] : {@_} ) }

=head1 NAME

Catalyst::Request::Upload - handles file upload requests

=head1 SYNOPSIS

    $upload->copy_to;
    $upload->fh;
    $upload->filename;
    $upload->headers;
    $upload->link_to;
    $upload->size;
    $upload->slurp;
    $upload->tempname;
    $upload->type;

See also L<Catalyst>.

=head1 DESCRIPTION

This class provides accessors and methods to handle client upload requests.

=head1 METHODS

=head2 $upload->new

Simple constructor.

=head2 $upload->copy_to

Copies the temporary file using L<File::Copy>. Returns true for success,
false for failure.

     $upload->copy_to('/path/to/target');

=cut

sub copy_to {
    my $self = shift;
    return File::Copy::copy( $self->tempname, @_ );
}

=head2 $upload->fh

Opens a temporary file (see tempname below) and returns an L<IO::File> handle.

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

=head2 $upload->filename

Returns the client-supplied filename.

=head2 $upload->headers

Returns an L<HTTP::Headers> object for the request.

=head2 $upload->link_to

Creates a hard link to the temporary file. Returns true for success, 
false for failure.

    $upload->link_to('/path/to/target');

=cut

sub link_to {
    my ( $self, $target ) = @_;
    return CORE::link( $self->tempname, $target );
}

=head2 $upload->size

Returns the size of the uploaded file in bytes.

=head2 $upload->slurp

Returns a scalar containing the contents of the temporary file.

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

=head2 $upload->tempname

Returns the path to the temporary file.

=head2 $upload->type

Returns the client-supplied Content-Type.

=head1 AUTHORS

Sebastian Riedel, C<sri@cpan.org>

Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
