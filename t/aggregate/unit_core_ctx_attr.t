use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$FindBin::Bin/../lib";
use Test::More;
use URI;

use_ok('TestApp');

my $request = Catalyst::Request->new( {
                base => URI->new('http://127.0.0.1/foo')
              } );
my $dispatcher = TestApp->dispatcher;
my $context = TestApp->new( {
                request => $request,
                namespace => 'yada',
              } );

is(        $context->hello_lazy,    'hello there', '$context->hello_lazy');
eval { is( $context->hello_notlazy, 'hello there', '$context->hello_notlazy') };
if ($@) {
   fail('$context->hello_notlazy');
   warn $@;
}

done_testing;

