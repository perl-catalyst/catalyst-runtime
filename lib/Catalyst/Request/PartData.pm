package Catalyst::Request::PartData;

use Moose;
use HTTP::Headers;
use Encode;

has [qw/raw_data name size/] => (is=>'ro', required=>1);

has headers => (
  is=>'ro',
  required=>1,
  handles=>[qw/content_type content_encoding content_type_charset/]);

sub build_from_part_data {
  my ($class, $c, $part_data) = @_;

  # If the headers are complex, we need to work harder to figure out what to do
  if(my $hdrs = $class->part_data_has_complex_headers($part_data)) {

    # Ok so its one of two possibilities.  If I can inspect the headers and
    # Figure out what to do, the I will return data.  Otherwise I will return
    # a PartData object and expect you do deal with it.
    # For now if I can find a charset in the content type I will just decode and
    # assume I got it right (patches and bug reports welcomed).

    # Any of these headers means I can't decode

    if(
        $hdrs->content_encoding
    ) {
      return $class->new(
        raw_data => $part_data->{data},
        name => $part_data->{name},
        size => $part_data->{size},
        headers => HTTP::Headers->new(%{ $part_data->{headers} }));
    }

    my ($ct, $charset) = $hdrs->content_type_charset;

    if($ct) {
      # Good news, we probably have data we can return.  If there is a charset
      # then use that to decode otherwise use the default decoding.
      if($charset) {
        return  Encode::decode($charset, $part_data->{data})
      } else {
        if($c and $c->encoding and !$c->config->{skip_body_param_unicode_decoding}) {
          return $c->_handle_param_unicode_decoding($part_data->{data});
        } else {
          return $part_data->{data}
        }
      }
    } else {
      # I have no idea what to do with this now..
      return $class->new(
        raw_data => $part_data->{data},
        name => $part_data->{name},
        size => $part_data->{size},
        headers => HTTP::Headers->new(%{ $part_data->{headers} }));
    }
  } else {
    if($c and $c->encoding and !$c->config->{skip_body_param_unicode_decoding}) {
      return $c->_handle_param_unicode_decoding($part_data->{data});
    } else {
      return $part_data->{data}
    }
  }

  return $part_data->{data} unless $class->part_data_has_complex_headers($part_data);
  return $class->new(
    raw_data => $part_data->{data},
    name => $part_data->{name},
    size => $part_data->{size},
    headers => HTTP::Headers->new(%{ $part_data->{headers} }));
}

sub part_data_has_complex_headers {
  my ($class, $part_data) = @_;
  my %h = %{$part_data->{headers}};
  my $hdrs = HTTP::Headers->new(%h);

  # Remove non threatening headers.
  $hdrs->remove_header('Content-Length', 'Expires', 'Last-Modified', 'Content-Language');

  # If we still have more than one (Content-Disposition) header we need to understand
  # that and deal with it.

  return $hdrs->header_field_names > 1 ? $hdrs :0;
}

__PACKAGE__->meta->make_immutable;

=head1 NAME

Catalyst::Request::Upload - handles file upload requests

=head1 SYNOPSIS

    my $data_part = 

To specify where Catalyst should put the temporary files, set the 'uploadtmp'
option in the Catalyst config. If unset, Catalyst will use the system temp dir.

    __PACKAGE__->config( uploadtmp => '/path/to/tmpdir' );

See also L<Catalyst>.

=head1 DESCRIPTION

=head1 ATTRIBUTES

This class defines the following immutable attributes

=head2 raw_data

The raw data as returned via L<HTTP::Body>.

=head2 name

The part name that gets extracted from the content-disposition header.

=head2 size

The raw byte count (over http) of the data.  This is not the same as the character
length

=head2 headers

An L<HTTP::Headers> object that represents the submitted headers of the POST.  This
object will handle the following methods:

=head3 content_type

=head3 content_encoding

=head3 content_type_charset

These three methods are the same as methods described in L<HTTP::Headers>.

=head1 METHODS

=head2 build_from_part_data

Factory method to build an object from part data returned by L<HTTP::Body>

=head2 part_data_has_complex_headers

Returns true if there more than one header (indicates the part data is complex and
contains content type and encoding information.).

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
