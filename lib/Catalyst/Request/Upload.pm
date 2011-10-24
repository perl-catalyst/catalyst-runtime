package Catalyst::Request::Upload;

use Moose;
with 'MooseX::Emulate::Class::Accessor::Fast';

use Catalyst::Exception;
use File::Copy ();
use IO::File ();
use File::Spec::Unix;
use namespace::clean -except => 'meta';

has filename => (is => 'rw');
has headers => (is => 'rw');
has size => (is => 'rw');
has tempname => (is => 'rw');
has type => (is => 'rw');
has basename => (is => 'ro', lazy_build => 1);

has fh => (
  is => 'rw',
  required => 1,
  lazy => 1,
  default => sub {
    my $self = shift;

    my $fh = IO::File->new($self->tempname, IO::File::O_RDONLY);
    unless ( defined $fh ) {
      my $filename = $self->tempname;
      Catalyst::Exception->throw(
          message => qq/Can't open '$filename': '$!'/ );
    }

    return $fh;
  },
);

sub _build_basename {
    my $self = shift;
    my $basename = $self->filename;
    $basename =~ s|\\|/|g;
    $basename = ( File::Spec::Unix->splitpath($basename) )[2];
    $basename =~ s|[^\w\.-]+|_|g;
    return $basename;
}

no Moose;

=for stopwords uploadtmp

=head1 NAME

Catalyst::Request::Upload - handles file upload requests

=head1 SYNOPSIS

    my $upload = $c->req->upload('field');

    $upload->basename;
    $upload->copy_to;
    $upload->fh;
    $upload->filename;
    $upload->headers;
    $upload->link_to;
    $upload->size;
    $upload->slurp;
    $upload->tempname;
    $upload->type;

To specify where Catalyst should put the temporary files, set the 'uploadtmp'
option in the Catalyst config. If unset, Catalyst will use the system temp dir.

    __PACKAGE__->config( uploadtmp => '/path/to/tmpdir' );

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

Note that this will cause the filehandle pointed to by C<< $upload->fh >> to
be reset to the start of the file using seek and the file handle to be put
into binary mode.

=cut

sub slurp {
    my ( $self, $layer ) = @_;

    unless ($layer) {
        $layer = ':raw';
    }

    my $content = undef;
    my $handle  = $self->fh;

    binmode( $handle, $layer );

    $handle->seek(0, IO::File::SEEK_SET);
    while ( $handle->sysread( my $buffer, 8192 ) ) {
        $content .= $buffer;
    }

    $handle->seek(0, IO::File::SEEK_SET);
    return $content;
}

=head2 $upload->basename

Returns basename for C<filename>.

=head2 $upload->tempname

Returns the path to the temporary file.

=head2 $upload->type

Returns the client-supplied Content-Type.

=head2 meta

Provided by Moose

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
