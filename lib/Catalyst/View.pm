package Catalyst::View;

use strict;
use base qw/Catalyst::Component/;

=head1 NAME

Catalyst::View - Catalyst View base class

=head1 SYNOPSIS

    package Catalyst::View::Homebrew;

    use base qw/Catalyst::View/;

    sub process {
    # template processing goes here.
    }

=head1 DESCRIPTION

This is the Catalyst View base class. It's meant to be used as 
a base class by Catalyst views.

As a convention, views are expected to read template names from 
$c->stash->{template}, and put the output into $c->res->body.
Some views default to render a template named after the dispatched
action's private name. (See L<Catalyst::Action>.)

=head1 METHODS 

Implements the same methods as other Catalyst components, see
L<Catalyst::Component>

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>
Marcus Ramberg, C<mramberg@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
