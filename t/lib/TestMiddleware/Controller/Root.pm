package TestMiddleware::Controller::Root;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub default : Path { }
sub welcome : Path(welcome) {
  pop->res->body('Welcome to Catalyst');
}

__PACKAGE__->meta->make_immutable;
