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
has raw_basename => (is => 'ro', lazy_build => 1);
has charset => (is=>'ro', predicate=>'has_charset');

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
    my $basename = shift->raw_basename;
    $basename =~ s|[^\w\.-]+|_|g;
    return $basename;
}

sub _build_raw_basename {
    my $self = shift;
    my $basename = $self->filename;
    $basename =~ s|\\|/|g;
    $basename = ( File::Spec::Unix->splitpath($basename) )[2];
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
    $upload->decoded_fh
    $upload->filename;
    $upload->headers;
    $upload->link_to;
    $upload->size;
    $upload->slurp;
    $upload->decoded_slurp;
    $upload->tempname;
    $upload->type;
    $upload->charset;

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

=head2 $upload->is_utf8_encoded

Returns true of the upload defines a character set at that value is 'UTF-8'.
This does not try to inspect your upload and make any guesses if the Content
Type charset is undefined.

=cut

sub is_utf8_encoded {
    my $self = shift;
    if(my $charset = $self->charset) {
      return $charset eq 'UTF-8' ? 1 : 0;
    }
    return 0;
}

=head2 $upload->fh

Opens a temporary file (see tempname below) and returns an L<IO::File> handle.

This is a filehandle that is opened with no additional IO Layers.

=head2 $upload->decoded_fh(?$encoding)

Returns a filehandle that has binmode set to UTF-8 if a UTF-8 character set
is found. This also accepts an override encoding value that you can use to
force a particular L<PerlIO> layer.  If neither are found the filehandle is
set to :raw.

This is useful if you are pulling the file into code and inspecting bit and
maybe then sending those bits back as the response.  (Please not this is not
a suitable filehandle to set in the body; use C<fh> if you are doing that).

Please note that using this method sets the underlying filehandle IO layer
so once you use this method if you go back and use the C<fh> method you
still get the IO layer applied.

=cut

sub decoded_fh {
    my ($self, $layer) = @_;
    my $fh  = $self->fh;

    $layer = ":encoding(UTF-8)" if !$layer && $self->is_utf8_encoded;
    $layer = ':raw' unless $layer;

    binmode($fh, $layer);
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

=head2 $upload->slurp(?$encoding)

Optionally accepts an argument to define an IO Layer (which is applied to
the filehandle via binmode; if no layer is defined the default is set to
":raw".

Returns a scalar containing the contents of the temporary file.

Note that this will cause the filehandle pointed to by C<< $upload->fh >> to
be reset to the start of the file using seek and the file handle to be put
into whatever encoding mode is applied.

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

=head2 $upload->decoded_slurp(?$encoding)

Works just like C<slurp> except we use C<decoded_fh> instead of C<fh> to
open a filehandle to slurp.  This means if your upload charset is UTF8
we binmode the filehandle to that encoding.

=cut

sub decoded_slurp {
    my ( $self, $layer ) = @_;
    my $handle = $self->decoded_fh($layer);

    my $content = undef;
    $handle->seek(0, IO::File::SEEK_SET);
    while ( $handle->sysread( my $buffer, 8192 ) ) {
        $content .= $buffer;
    }

    $handle->seek(0, IO::File::SEEK_SET);
    return $content;
}

=head2 $upload->basename

Returns basename for C<filename>.  This filters the name through a regexp
C<basename =~ s|[^\w\.-]+|_|g> to make it safe for filesystems that don't
like advanced characters.  This will of course filter UTF8 characters.
If you need the exact basename unfiltered use C<raw_basename>.

=head2 $upload->raw_basename

Just like C<basename> but without filtering the filename for characters that
don't always write to a filesystem.

=head2 $upload->tempname

Returns the path to the temporary file.

=head2 $upload->type

Returns the client-supplied Content-Type.

=head2 $upload->charset

The character set information part of the content type, if any.  Useful if you
need to figure out any encodings on the file upload.

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
