package TestAppOneView::View::Dummy;

use base 'Catalyst::View';

sub COMPONENT {
    bless {}, 'AClass'
}

package AClass;

### Turning this off on purpose to test out instances
### without COMPONENT or subclassing

#use base 'Catalyst::View';

1;
