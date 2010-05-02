package TestApp::Plugin::ParameterizedRole;

use MooseX::Role::Parameterized;
use namespace::autoclean;

parameter method_name => (
    isa      => 'Str',
    required => 1,
);

role {
    my $p = shift;
    my $method_name = $p->method_name;

    method $method_name => sub { 'birne' };
};

1;
