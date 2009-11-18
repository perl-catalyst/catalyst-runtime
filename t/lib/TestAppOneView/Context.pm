package TestAppOneView::Context;
use Moose;
extends 'Catalyst::Context'; 

# Replace the very large HTML error page with
# useful info if something crashes during a test
sub finalize_error {
    my $c = shift;

    $c->next::method(@_);

    $c->res->status(500);
    $c->res->body( 'FATAL ERROR: ' . join( ', ', @{ $c->error } ) );
}

1;

