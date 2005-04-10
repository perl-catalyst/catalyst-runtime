package Catalyst::Request;

use strict;
use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(
    qw/action address arguments base cookies headers hostname match method
      parameters path snippets uploads/
);

*args   = \&arguments;
*params = \&parameters;

sub content_encoding { shift->headers->content_encoding(@_) }
sub content_length   { shift->headers->content_length(@_)   }
sub content_type     { shift->headers->content_type(@_)     }
sub header           { shift->headers->header(@_)           }
sub referer          { shift->headers->referer(@_)          }
sub user_agent       { shift->headers->user_agent(@_)       }

sub _assign_values {
    my ( $self, $map, $values ) = @_;

    while ( my ( $name, $value ) = splice( @{$values}, 0, 2 ) ) {

        if ( exists $map->{$name} ) {
            for ( $map->{$name} ) {
                $_ = [$_] unless ref($_) eq "ARRAY";
                push( @$_, $value );
            }
        }
        else {
            $map->{$name} = $value;
        }
    }
}

=head1 NAME

Catalyst::Request - Catalyst Request Class

=head1 SYNOPSIS


    $req = $c->request;
    $req->action;
    $req->address;
    $req->args;
    $req->arguments;
    $req->base;
    $req->content_encoding;
    $req->content_length;
    $req->content_type;
    $req->cookies;
    $req->header;
    $req->headers;
    $req->hostname;
    $req->match;
    $req->method;
    $req->param;
    $req->params;
    $req->parameters;
    $req->path;
    $req->referer;
    $req->snippets;
    $req->upload;
    $req->uploads;
    $req->user_agent

See also L<Catalyst>.

=head1 DESCRIPTION

This is the Catalyst Request class, which provides a set of accessors to the
request data.  The request object is prepared by the specialized Catalyst
Engine module thus hiding the details of the particular engine implementation.


=head1 METHODS

=over 4

=item $req->action

Contains the requested action.

    print $c->request->action;

=item $req->address

Contains the remote address.

    print $c->request->address

=item $req->args

Shortcut for arguments

=item $req->arguments

Returns a reference to an array containing the arguments.

    print $c->request->arguments->[0];

=item $req->base

Contains the url base. This will always have a trailing slash.

=item $req->content_encoding

Shortcut to $req->headers->content_encoding

=item $req->content_length

Shortcut to $req->headers->content_length

=item $req->content_type

Shortcut to $req->headers->content_type

=item $req->cookies

Returns a reference to a hash containing the cookies.

    print $c->request->cookies->{mycookie}->value;

=item $req->header

Shortcut to $req->headers->header

=item $req->headers

Returns an L<HTTP::Headers> object containing the headers.

    print $c->request->headers->header('X-Catalyst');

=item $req->hostname

Contains the hostname of the remote user.

    print $c->request->hostname

=item $req->match

This contains be the matching part of a regexp action. otherwise it
returns the same as 'action'.

    print $c->request->match;

=item $req->method

Contains the request method (C<GET>, C<POST>, C<HEAD>, etc).

    print $c->request->method;

=item $req->param

Get request parameters with a CGI.pm like param method.

    $value  = $c->request->param('foo');
    @values = $c->request->param('foo');
    @params = $c->request->param;

=cut

sub param {
    my $self = shift;

    if ( @_ == 0 ) {
        return keys %{ $self->parameters };
    }

    my $param = shift;

    unless ( exists $self->parameters->{$param} ) {
        return wantarray ? () : undef;
    }

    if ( ref $self->parameters->{$param} eq 'ARRAY' ) {
        return (wantarray)
          ? @{ $self->parameters->{$param} }
          : $self->parameters->{$param}->[0];
    }
    else {
        return (wantarray)
          ? ( $self->parameters->{$param} )
          : $self->parameters->{$param};
    }
}

=item $req->params

Shortcut for $req->parameters.

=item $req->parameters

Returns a reference to a hash containing parameters. Values can
be either a scalar or a arrayref containing scalars.

    print $c->request->parameters->{field};
    print $c->request->parameters->{field}->[0];

=item $req->path

Contains the path.

    print $c->request->path;

=item $req->referer

Shortcut to $req->headers->referer. Referring page.

=item $req->snippets

Returns a reference to an array containing regex snippets.

    my @snippets = @{ $c->request->snippets };

=item $req->upload

A convenient method to $req->uploads.

    $upload  = $c->request->upload('field');
    @uploads = $c->request->upload('field');
    @fields  = $c->request->upload;
    
    for my $upload ( $c->request->upload('field') ) {
        print $upload->filename;
    }

=cut

sub upload {
    my $self = shift;

    if ( @_ == 0 ) {
        return keys %{ $self->uploads };
    }

    my $upload = shift;

    unless ( exists $self->uploads->{$upload} ) {
        return wantarray ? () : undef;
    }

    if ( ref $self->uploads->{$upload} eq 'ARRAY' ) {
        return (wantarray)
          ? @{ $self->uploads->{$upload} }
          : $self->uploads->{$upload}->[0];
    }
    else {
        return (wantarray)
          ? ( $self->uploads->{$upload} )
          : $self->uploads->{$upload};
    }
}

=item $req->uploads

Returns a reference to a hash containing uploads. Values can be either a 
hashref or a arrayref containing C<Catalyst::Request::Upload> objects.

    my $upload = $c->request->uploads->{field};
    my $upload = $c->request->uploads->{field}->[0];

=item $req->user_agent

Shortcut to $req->headers->user_agent. User Agent version string.

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Marcus Ramberg, C<mramberg@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
