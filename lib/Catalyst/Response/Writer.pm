package Catalyst::Response::Writer;

sub write { shift->{_writer}->write(@_) }
sub close { shift->{_writer}->close }

sub write_encoded {
  my ($self, $line) = @_;
  if((my $enc = $self->{_context}->encoding) && $self->{_requires_encoding}) {
    # Not going to worry about CHECK arg since Unicode always croaks I think - jnap
    $line = $enc->encode($line);
  }

  $self->write($line);
}

=head1 NAME

Catalyst::Response::Writer - Proxy over the PSGI Writer

=head1 SYNOPSIS

    sub myaction : Path {
      my ($self, $c) = @_;
      my $w = $c->response->writer_fh;

      $w->write("hello world");
      $w->close;
    }

=head1 DESCRIPTION

This wraps the PSGI writer (see L<PSGI.pod\Delayed-Response-and-Streaming-Body>)
for more.  We wrap this object so we can provide some additional methods that
make sense from inside L<Catalyst>

=head1 METHODS

This class does the following methods

=head2 write

=head2 close

These delegate to the underlying L<PSGI> writer object

=head2 write_encoded

If the application defines a response encoding (default is UTF8) and the 
content type is a type that needs to be encoded (text types like HTML or XML and
Javascript) we first encode the line you want to write.  This is probably the
thing you want to always do.  If you use the L<\write> method directly you will
need to handle your own encoding.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
