use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;

lives_ok {
    package TestApp::TestCustomRequest;
    use strict;
    use warnings;
    use base qw/Catalyst::Request/;

    # Catalyst::Request::REST uses this, so test it in core..
    __PACKAGE__->mk_accessors(qw( custom_accessor ));
} 'Can make a custom request class';


