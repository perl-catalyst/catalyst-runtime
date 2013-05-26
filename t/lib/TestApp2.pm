package TestApp2;
use strict;
use warnings;
use base qw/Catalyst/;
use Catalyst qw/Params::Nested/;

__PACKAGE__->config(
  'name' => 'TestApp2',
  encoding => 'UTF-8',
);

__PACKAGE__->setup;

sub handle_unicode_encoding_exception {
  my ( $self, $param_value, $error_msg ) = @_;
  return $param_value;
}

1;
