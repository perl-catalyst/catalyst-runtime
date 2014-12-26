package TestAppUnicode;
use strict;
use warnings;
use TestLogger;
use base qw/Catalyst/;
use Catalyst;

__PACKAGE__->config(
  'name' => 'TestAppUnicode',
  $ENV{TESTAPP_ENCODING} ? ( encoding => $ENV{TESTAPP_ENCODING} ) : (),
);

__PACKAGE__->log(TestLogger->new);

__PACKAGE__->setup;

sub handle_unicode_encoding_exception {
  my ( $self, $param_value, $error_msg ) = @_;
  return $param_value;
}

1;
