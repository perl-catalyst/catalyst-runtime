package Catalyst::Component::Role::CaptureApp;

use Moose::Role;
use namespace::clean -except => 'meta';

# Future - isa => 'ClassName|Catalyst' performance?
#           required => 1 breaks tests..
has _application => (is => 'ro', weak_ref => 1);
sub _app { (shift)->_application(@_) }

override BUILDARGS => sub {
    my ($self, $app) = @_;

    my $args = super();
    $args->{_application} = $app;

    return $args;
};

1;
