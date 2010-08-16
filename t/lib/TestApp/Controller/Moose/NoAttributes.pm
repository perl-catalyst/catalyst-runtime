package TestApp::Controller::Moose::NoAttributes;
use Moose;
extends qw/Catalyst::Controller/;

__PACKAGE__->config(
   actions => {
       test => { Local => undef }
   }
);

sub test {
}

no Moose;
1;

