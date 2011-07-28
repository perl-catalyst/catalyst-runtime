package TestAppContainer;
use Moose;
use Catalyst;
extends 'Catalyst';

our $VERSION = '0.01';

__PACKAGE__->config(applevel_config => 'foo');

__PACKAGE__->setup;

sub finalize_config {
    my $c = shift;
    $c->config( foo => 'bar' );
    $c->next::method( @_ );
}

1;
