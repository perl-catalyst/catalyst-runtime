package TestAppUnicode;
use strict;
use warnings;
use TestLogger;
use base qw/Catalyst/;
use Catalyst qw/Unicode::Encoding Params::Nested/;

__PACKAGE__->config(
  encoding => $ENV{TESTAPP_ENCODING}
) if $ENV{TESTAPP_ENCODING};

__PACKAGE__->config('name' => 'TestAppUnicode');

__PACKAGE__->log(TestLogger->new);

__PACKAGE__->setup;

sub handle_unicode_encoding_exception {
  my ( $self, $param_value, $error_msg ) = @_;
  return $param_value;
}

1;
