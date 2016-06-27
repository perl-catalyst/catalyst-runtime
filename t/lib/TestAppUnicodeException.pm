package TestAppUnicodeException;
use strict;
use warnings;
use base qw/Catalyst/;

__PACKAGE__->config(
  'name' => 'TestApp2',
  encoding => 'UTF-8',
);

__PACKAGE__->setup;

sub handle_unicode_encoding_exception {
  my ( $self, $param_value, $error_msg ) = @_;
  $self->response->body("Bad unicode data");
  $self->response->status("200");
  $self->detach();
  # [error] Caught exception in engine "catalyst_detach"

  # the point here is to avoid the error screaming.

  # with $self->finalize we get instead:
  # $self->finalize;

  # [warn] Useless setting a header value after finalize_headers and the response callback has been called. Since we don't support tail headers this will not work as you might expect.
  # [error] Caught exception in engine "Can't use an undefined value as a subroutine reference at lib/Catalyst/Response.pm line 52."

  return;
}

1;
