package Catalyst::Request;

use strict;
use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(
    qw/action address arguments base cookies headers hostname match method
      parameters path snippets uploads/
);

*args   = \&arguments;
*params = \&parameters;

=head1 NAME

Catalyst::Request - Catalyst Request Class

=head1 SYNOPSIS


    $req = $c->request;
    $req->action;
    $req->address;
    $req->args;
    $req->arguments;
    $req->base;
    $req->cookies;
    $req->headers;
    $req->hostname;
    $req->match;
    $req->method;
    $req->parameters;
    $req->params;
    $req->path;
    $req->snippets;
    $req->uploads;

See also L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst Request class, which provides a set of accessors to the
request data.  The request object is prepared by the specialized Catalyst
Engine module thus hiding the details of the particular engine implementation.


=head1 METHODS

=over 4

=item $req->action

Contains the action.

    print $c->request->action;

=item $req->address

Contains the remote address.

    print $c->request->address

=item $req->arguments

=item $req->args

Returns a reference to an array containing the arguments.

    print $c->request->arguments->[0];

=item $req->base

Contains the uri base.

=item $req->cookies

Returns a reference to a hash containing the cookies.

    print $c->request->cookies->{mycookie}->value;

=item $req->headers

Returns an L<HTTP::Headers> object containing the headers.

    print $c->request->headers->header('X-Catalyst');

=item $req->hostname

Contains the remote hostname.

    print $c->request->hostname

=item $req->match

Contains the match.

    print $c->request->match;

=item $req->parameters

=item $req->params

Returns a reference to a hash containing the parameters.

    print $c->request->parameters->{foo};

=item $req->path

Contains the path.

    print $c->request->path;

=item $req->method

Contains the request method (C<GET>, C<POST>, C<HEAD>, etc).

    print $c->request->method

=item $req->snippets

Returns a reference to an array containing regex snippets.

    my @snippets = @{ $c->request->snippets };

=item $req->uploads

Returns a reference to a hash containing the uploads.

    my $filename = $c->req->parameters->{foo};
    print $c->request->uploads->{$filename}->{type};
    print $c->request->uploads->{$filename}->{size};
    my $fh = $c->request->uploads->{$filename}->{fh};
    my $content = do { local $/; <$fh> };

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
