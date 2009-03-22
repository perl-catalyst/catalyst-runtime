package TestAppMetaCompat::Action::UsesCAF;

use strict;

use base qw/Catalyst::Action Class::Accessor::Fast/;
__PACKAGE__->mk_accessors(qw/ foo /);

1;
