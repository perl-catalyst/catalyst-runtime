use Test::More tests => 1;
use strict;
use warnings;

{
  package MyApp::Component;
  use Test::More;

  sub COMPONENT {
    fail 'This no longer gets dispatched to';
  }

  package MyApp::MyComponent;

  use base 'Catalyst::Component', 'MyApp::Component';

}

my $warn = '';
{
  local $SIG{__WARN__} = sub {
    $warn .= $_[0];
  };
  MyApp::MyComponent->COMPONENT('MyApp');
}

like($warn, qr/after Catalyst::Component in MyApp::Component/,
    'correct warning thrown');

