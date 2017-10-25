package Catalyst::Component::ContextClosure;

use Moose::Role;
use Scalar::Util 'weaken';
use namespace::autoclean;

sub make_context_closure {
    my ($self, $closure, $ctx) = @_;
    weaken $ctx;
    return sub { $closure->($ctx, @_) };
}

1;

__END__

=head1 NAME

Catalyst::Component::ContextClosure - Moose Role for components which need to close over the $ctx, without leaking

=head1 SYNOPSIS

    package MyApp::Controller::Foo;
    use Moose;
    use namespace::clean -except => 'meta';
    BEGIN {
        extends 'Catalyst::Controller';
        with 'Catalyst::Component::ContextClosure';
    }

    sub some_action : Local {
        my ($self, $ctx) = @_;
        $ctx->stash(a_closure => $self->make_context_closure(sub {
            my ($ctx) = @_;
            $ctx->response->body('body set from closure');
        }, $ctx));
    }

=head1 DESCRIPTION

A common problem with stashing a closure, that closes over the Catalyst context
(often called C<$ctx> or C<$c>), is the circular reference it creates, as the
closure holds onto a reference to context, and the context holds a reference to
the closure in its stash. This creates a memory leak, unless you always
carefully weaken the closures context reference.

This role provides a convenience method to create closures, that closes over
C<$ctx>.

=head1 METHODS

=head2 make_context_closure ($closure, $ctx)

Returns a code reference, that will invoke C<$closure> with a weakened
reference to C<$ctx>. All other parameters to the returned code reference will
be passed along to C<$closure>.

=head1 SEE ALSO

L<Catalyst::Component>

L<Catalyst::Controller>

L<CatalystX::LeakChecker>

=begin stopwords

=head1 AUTHOR

Florian Ragwitz <rafl@debian.org>

=end stopwords

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
