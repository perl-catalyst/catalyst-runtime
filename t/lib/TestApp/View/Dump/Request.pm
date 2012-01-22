package TestApp::View::Dump::Request;

use strict;
use base qw[TestApp::View::Dump];

sub process {
    my ( $self, $c ) = @_;
    my $r = $c->request;
    local $r->{env};
    return $self->SUPER::process( $c, $r );
}

1;
