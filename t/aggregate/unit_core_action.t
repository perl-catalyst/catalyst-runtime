use Test::More tests => 6;
use strict;
use warnings;
use Moose::Meta::Class;
#use Moose::Meta::Attribute;
use Catalyst::Request;

use_ok('Catalyst::Action');

my $action_1 = Catalyst::Action->new(
  name => 'foo',
  code => sub { "DUMMY" },
  reverse => 'bar/foo',
  namespace => 'bar',
  attributes => {
    Args => [ 1 ],
    attr2 => [ 2 ],
  },
);

my $action_2 = Catalyst::Action->new(
  name => 'foo',
  code => sub { "DUMMY" },
  reverse => 'bar/foo',
  namespace => 'bar',
  attributes => {
    Args => [ 2 ],
    attr2 => [ 2 ],
  },
);

is("${action_1}", $action_1->reverse, 'overload string');
is($action_1->(), 'DUMMY', 'overload code');

my $anon_meta = Moose::Meta::Class->create_anon_class(
  attributes => [
    Moose::Meta::Attribute->new(
      request => (
        reader => 'request',
        required => 1,
        default => sub { Catalyst::Request->new(arguments => [qw/one two/]) },
      ),
    ),
  ],
  methods => { req => sub { shift->request(@_) } }
);

my $mock_c = $anon_meta->new_object();
$mock_c->request;

ok(!$action_1->match($mock_c), 'bad match fails');
ok($action_2->match($mock_c), 'good match works');

ok($action_2->compare( $action_1 ), 'compare works');
