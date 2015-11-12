use warnings;
use strict;
use Test::More;
use FindBin qw< $Bin >;
use Safe::Isa qw< $_isa >;
use lib "$Bin/lib";
use constant App => 'TestAppArgsEmptyParens';
use Catalyst::Test App;

my $chained = App->dispatcher->dispatch_type('Chained');

for (1..2) {
    is((scalar grep { $_->$_isa("Catalyst::Action") } @{ $chained->_endpoints }), 2, "Two Catalyst::Actions in _endpoints")
        or diag "  _endpoints: ", explain $chained->_endpoints;

    eval { $chained->list(App) };
    ok !$@, "->list didn't die"
        or diag "Died with: $@";
}

done_testing;
