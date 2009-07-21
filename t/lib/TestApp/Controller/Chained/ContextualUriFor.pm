package TestApp::Controller::Chained::ContextualUriFor;

use parent q(Catalyst::Controller);

__PACKAGE__->config->{namespace} = q();

sub base             : Chained(/) PathPart('') CaptureArgs(0) {}
sub default_endpoint : Chained(base) PathPart('') Args(0) {}
sub just_one_arg     : Chained(base) Args(1) {}
sub leading_capture  : Chained(base) PathPart('') CaptureArgs(1) {}
sub midpoint_capture : Chained(leading_capture) CaptureArgs(1) {}
sub slurpy_endpoint  : Chained(midpoint_capture) Args {}

1;
