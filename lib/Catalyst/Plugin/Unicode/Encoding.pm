package Catalyst::Plugin::Unicode::Encoding;

use strict;
use base 'Class::Data::Inheritable';

use Carp ();
use MRO::Compat;
use Try::Tiny;

use Encode 2.21 ();
our $CHECK = Encode::FB_CROAK | Encode::LEAVE_SRC;

our $VERSION = '2.1';

__PACKAGE__->mk_classdata('_encoding');

sub encoding {
    my $c = shift;
    my $encoding;

    if ( scalar @_ ) {
        # Let it be set to undef
        if (my $wanted = shift)  {
            $encoding = Encode::find_encoding($wanted)
              or Carp::croak( qq/Unknown encoding '$wanted'/ );
        }

        $encoding = ref $c
                  ? $c->{encoding} = $encoding
                  : $c->_encoding($encoding);
    } else {
      $encoding = ref $c && exists $c->{encoding}
                ? $c->{encoding}
                : $c->_encoding;
    }

    return $encoding;
}

sub finalize_headers {
    my $c = shift;

    my $body = $c->response->body;

    return $c->next::method(@_)
      unless defined($body);

    my $enc = $c->encoding;

    return $c->next::method(@_)
      unless $enc;

    my ($ct, $ct_enc) = $c->response->content_type;

    # Only touch 'text-like' contents
    return $c->next::method(@_)
      unless $c->response->content_type =~ /^text|xml$|javascript$/;

    if ($ct_enc && $ct_enc =~ /charset=([^;]*)/) {
        if (uc($1) ne uc($enc->mime_name)) {
            $c->log->debug("Unicode::Encoding is set to encode in '" .
                           $enc->mime_name .
                           "', content type is '$1', not encoding ");
            return $c->next::method(@_);
        }
    } else {
        $c->res->content_type($c->res->content_type . "; charset=" . $enc->mime_name);
    }

    # Encode expects plain scalars (IV, NV or PV) and segfaults on ref's
    $c->response->body( $c->encoding->encode( $body, $CHECK ) )
        if ref(\$body) eq 'SCALAR';

    $c->next::method(@_);
}

# Note we have to hook here as uploads also add to the request parameters
sub prepare_uploads {
    my $c = shift;

    $c->next::method(@_);

    my $enc = $c->encoding;
    return unless $enc;

    for my $key (qw/ parameters query_parameters body_parameters /) {
        for my $value ( values %{ $c->request->{$key} } ) {
            # N.B. Check if already a character string and if so do not try to double decode.
            #      http://www.mail-archive.com/catalyst@lists.scsys.co.uk/msg02350.html
            #      this avoids exception if we have already decoded content, and is _not_ the
            #      same as not encoding on output which is bad news (as it does the wrong thing
            #      for latin1 chars for example)..
            $value = $c->_handle_unicode_decoding($value);
        }
    }
    for my $value ( values %{ $c->request->uploads } ) {
        # skip if it fails for uploads, as we don't usually want uploads touched
        # in any way
        for my $inner_value ( ref($value) eq 'ARRAY' ? @{$value} : $value ) {
            $inner_value->{filename} = try {
                $enc->decode( $inner_value->{filename}, $CHECK )
            } catch {
                $c->handle_unicode_encoding_exception({
                    param_value => $inner_value->{filename},
                    error_msg => $_,
                    encoding_step => 'uploads',
                });
            };
        }
    }
}

sub prepare_action {
    my $c = shift;

    my $ret = $c->next::method(@_);

    my $enc = $c->encoding;
    return $ret unless $enc;

    foreach (@{$c->req->arguments}, @{$c->req->captures}) {
      $_ = $c->_handle_param_unicode_decoding($_);
    }

    return $ret;
}

sub setup {
    my $self = shift;

    my $conf = $self->config;

    # Allow an explicit undef encoding to disable default of utf-8
    my $enc = delete $conf->{encoding};
    $self->encoding( $enc );

    return $self->next::method(@_)
      unless $self->setup_finished; ## hack to stop possibly meaningless test fail... (jnap)
}

sub _handle_unicode_decoding {
    my ( $self, $value ) = @_;

    return unless defined $value;

    if ( ref $value eq 'ARRAY' ) {
        foreach ( @$value ) {
            $_ = $self->_handle_unicode_decoding($_);
        }
        return $value;
    }
    elsif ( ref $value eq 'HASH' ) {
        foreach ( values %$value ) {
            $_ = $self->_handle_unicode_decoding($_);
        }
        return $value;
    }
    else {
        return $self->_handle_param_unicode_decoding($value);
    }
}

sub _handle_param_unicode_decoding {
    my ( $self, $value ) = @_;
    my $enc = $self->encoding;
    return try {
        Encode::is_utf8( $value ) ?
            $value
        : $enc->decode( $value, $CHECK );
    }
    catch {
        $self->handle_unicode_encoding_exception({
            param_value => $value,
            error_msg => $_,
            encoding_step => 'params',
        });
    };
}

sub handle_unicode_encoding_exception {
    my ( $self, $exception_ctx ) = @_;
    die $exception_ctx->{error_msg};
}

1;

__END__

=head1 NAME

Catalyst::Plugin::Unicode::Encoding - Unicode aware Catalyst

=head1 SYNOPSIS

    use Catalyst;

    MyApp->config( encoding => 'UTF-8' ); # A valid Encode encoding


=head1 DESCRIPTION

This plugin is automatically loaded by apps. Even though is not a core component
yet, it will vanish as soon as the code is fully integrated. For more
information, please refer to L<Catalyst/ENCODING>.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
