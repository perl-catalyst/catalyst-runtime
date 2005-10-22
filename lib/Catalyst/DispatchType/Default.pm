package Catalyst::DispatchType::Default;

use strict;
use base qw/Catalyst::DispatchType/;

sub prepare_action {
    my ($self, $c, $path) = @_;
    return if $path =~ m!/!; # Not at root yet, wait for it ...
    my $result = @{$c->get_action('default', $c->req->path, 1) || []}[-1];
    if ($result) {
        $c->action( $result->[0] );
        $c->namespace( $c->req->path );
        $c->req->action('default');
        $c->req->match('');
    }
}

1;
