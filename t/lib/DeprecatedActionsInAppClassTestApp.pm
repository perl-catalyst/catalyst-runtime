package DeprecatedActionsInAppClassTestApp;

use strict;
use warnings;
use Catalyst;

our $VERSION = '0.01';

__PACKAGE__->config( name => 'DeprecatedActionsInAppClassTestApp', root => '/some/dir' );
__PACKAGE__->log(DeprecatedActionsInAppClassTestApp::Log->new);
__PACKAGE__->setup;

sub foo : Local {
    my ($self, $c) = @_;
    $c->res->body('OK');
}

package DeprecatedActionsInAppClassTestApp::Log;
use strict;
use warnings;
use base qw/Catalyst::Log/;

our $warnings;

sub warn {
    my ($self, $warning) = @_;
    $warnings++ if $warning =~ /action methods .+ found defined/i;
}

1;
