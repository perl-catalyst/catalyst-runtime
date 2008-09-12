use Test::More tests => 2;
use strict;
use warnings;

{
  package MyApp::Component;
  use Test::More;

  sub COMPONENT {
    my $caller = caller;
    is($caller, 'Catalyst::Component', 'Correct method resolution');
  }

  package MyApp::MyComponent;

  use base 'Catalyst::Component', 'MyApp::Component';

}

{
  my $expects = qr/after Catalyst::Component in MyApp::Component/;
  local $SIG{__WARN__} = sub {
    like($_[0], $expects, 'correct warning thrown');
  };
  MyApp::MyComponent->COMPONENT('MyApp');
}
