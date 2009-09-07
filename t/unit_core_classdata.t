#!/usr/bin/perl

use strict;
use warnings;
use Scalar::Util qw/refaddr blessed/;
use Test::More tests => 37;

{
  package ClassDataTest;
  use Moose;
  with 'Catalyst::ClassData';

  package ClassDataTest2;
  use Moose;
  extends 'ClassDataTest';

}

  my $scalar = '100';
  my $arrayref = [];
  my $hashref = {};
  my $scalarref = \$scalar;
  my $coderef = sub { "beep" };

  my $scalar2 = '200';
  my $arrayref2 = [];
  my $hashref2 = {};
  my $scalarref2 = \$scalar2;
  my $coderef2 = sub { "beep" };

  my $scalar3 = '300';
  my $arrayref3 = [];
  my $hashref3 = {};
  my $scalarref3 = \$scalar3;
  my $coderef3 = sub { "beep" };


my @accessors = qw/_arrayref _hashref _scalarref _coderef _scalar/;
ClassDataTest->mk_classdata($_) for @accessors;
can_ok('ClassDataTest', @accessors);

ClassDataTest2->mk_classdata("beep", "meep");
is(ClassDataTest2->beep, "meep");

ClassDataTest->_arrayref($arrayref);
ClassDataTest->_hashref($hashref);
ClassDataTest->_scalarref($scalarref);
ClassDataTest->_coderef($coderef);
ClassDataTest->_scalar($scalar);

is(ref(ClassDataTest->_arrayref), 'ARRAY');
is(ref(ClassDataTest->_hashref), 'HASH');
is(ref(ClassDataTest->_scalarref), 'SCALAR');
is(ref(ClassDataTest->_coderef), 'CODE');
ok( !ref(ClassDataTest->_scalar) );
is(refaddr(ClassDataTest->_arrayref), refaddr($arrayref));
is(refaddr(ClassDataTest->_hashref), refaddr($hashref));
is(refaddr(ClassDataTest->_scalarref), refaddr($scalarref));
is(refaddr(ClassDataTest->_coderef), refaddr($coderef));
is(ClassDataTest->_scalar, $scalar);


is(ref(ClassDataTest2->_arrayref), 'ARRAY');
is(ref(ClassDataTest2->_hashref), 'HASH');
is(ref(ClassDataTest2->_scalarref), 'SCALAR');
is(ref(ClassDataTest2->_coderef), 'CODE');
ok( !ref(ClassDataTest2->_scalar) );
is(refaddr(ClassDataTest2->_arrayref), refaddr($arrayref));
is(refaddr(ClassDataTest2->_hashref), refaddr($hashref));
is(refaddr(ClassDataTest2->_scalarref), refaddr($scalarref));
is(refaddr(ClassDataTest2->_coderef), refaddr($coderef));
is(ClassDataTest2->_scalar, $scalar);

ClassDataTest2->_arrayref($arrayref2);
ClassDataTest2->_hashref($hashref2);
ClassDataTest2->_scalarref($scalarref2);
ClassDataTest2->_coderef($coderef2);
ClassDataTest2->_scalar($scalar2);

is(refaddr(ClassDataTest2->_arrayref), refaddr($arrayref2));
is(refaddr(ClassDataTest2->_hashref), refaddr($hashref2));
is(refaddr(ClassDataTest2->_scalarref), refaddr($scalarref2));
is(refaddr(ClassDataTest2->_coderef), refaddr($coderef2));
is(ClassDataTest2->_scalar, $scalar2);

is(refaddr(ClassDataTest->_arrayref), refaddr($arrayref));
is(refaddr(ClassDataTest->_hashref), refaddr($hashref));
is(refaddr(ClassDataTest->_scalarref), refaddr($scalarref));
is(refaddr(ClassDataTest->_coderef), refaddr($coderef));
is(ClassDataTest->_scalar, $scalar);

ClassDataTest->_arrayref($arrayref3);
ClassDataTest->_hashref($hashref3);
ClassDataTest->_scalarref($scalarref3);
ClassDataTest->_coderef($coderef3);
ClassDataTest->_scalar($scalar3);

is(refaddr(ClassDataTest->_arrayref), refaddr($arrayref3));
is(refaddr(ClassDataTest->_hashref), refaddr($hashref3));
is(refaddr(ClassDataTest->_scalarref), refaddr($scalarref3));
is(refaddr(ClassDataTest->_coderef), refaddr($coderef3));
is(ClassDataTest->_scalar, $scalar3);

my $i = bless {}, 'ClassDataTest';
$i->_scalar('foo');

