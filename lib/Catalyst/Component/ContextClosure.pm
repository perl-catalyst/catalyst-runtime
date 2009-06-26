package Catalyst::Component::ContextClosure;

use Moose::Role;
use Scalar::Util 'weaken';
use namespace::autoclean;

sub make_context_closure {
    my ($self, $closure, $ctx) = @_;
    my $weak_ctx = $ctx;
    weaken $ctx;
    return sub { $closure->($ctx, @_) };
}

1;
