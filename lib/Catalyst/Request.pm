package Catalyst::Request;

use strict;
use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(
    qw/action arguments base cookies headers match method parameters path
      snippets uploads user/
);

*args   = \&arguments;
*params = \&parameters;

=head1 NAME

Catalyst::Request - Catalyst Request Class

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

The Catalyst Request.

=head2 METHODS

=head3 action

Contains the action.

    print $c->request->action;

=head3 arguments (args)

Returns an arrayref containing the arguments.

    print $c->request->arguments->[0];

=head3 base

Contains the uri base.

=head3 cookies

Returns a hashref containing the cookies.

    print $c->request->cookies->{mycookie}->value;

=head3 headers

Returns a L<HTTP::Headers> object containing the headers.

    print $c->request->headers->header('X-Catalyst');

=head3 match

Contains the match.

    print $c->request->match;

=head3 parameters (params)

Returns a hashref containing the parameters.

    print $c->request->parameters->{foo};

=head3 path

Contains the path.

    print $c->request->path;

=head3 method

Contains the request method.

    print $c->request->method

=head3 snippets

Returns an arrayref containing regex snippets.

    my @snippets = @{ $c->request->snippets };

=head3 uploads

Returns a hashref containing the uploads.

    print $c->request->uploads->{foo}->filename;
    print $c->request->uploads->{foo}->type;
    print $c->request->uploads->{foo}->size;
    my $fh = $c->request->uploads->{foo}->fh;

=head3 user

Returns the user.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
