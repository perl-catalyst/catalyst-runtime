package TestAppContainer;

use strict;
use warnings;

use MRO::Compat;

use Catalyst;

our $VERSION = '0.01';

__PACKAGE__->setup;

sub finalize_config {
    my $c = shift;
    $c->config( foo => 'bar' );
    $c->next::method( @_ );
}

1;
