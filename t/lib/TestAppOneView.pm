package TestAppOneView;
use strict;
use warnings;
use Catalyst;
use TestAppOneView::Context;

TestAppOneView->context_class( 'TestAppOneView::Context' );

__PACKAGE__->setup;

1;
