use strict;
use Test::More tests => 1;

{
    package TestPlugin;
    use strict;

    sub setup {
        shift->maybe::next::method(@_);
    }
}
{
    package TestAppC3ErrorUseMoose;
    use Moose;

    use Catalyst::Runtime 5.80;

    use base qw/Catalyst/;
    use Catalyst qw/
        +TestPlugin
    /;
}

use Test::Fatal;
is exception {
    TestAppC3ErrorUseMoose->setup();
}, undef, 'No C3 error';

1;

