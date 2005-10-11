package Catalyst::Request;

use strict;
use base 'Class::Accessor::Fast';

use IO::Socket qw[AF_INET inet_aton];

__PACKAGE__->mk_accessors(
    qw/action address arguments base cookies headers match method
      protocol query_parameters secure snippets uri user/
);

*args         = \&arguments;
*body_params  = \&body_parameters;
*input        = \&body;
*params       = \&parameters;
*query_params = \&query_parameters;
*path_info    = \&path;

sub content_encoding { shift->headers->content_encoding(@_) }
sub content_length   { shift->headers->content_length(@_) }
sub content_type     { shift->headers->content_type(@_) }
sub header           { shift->headers->header(@_) }
sub referer          { shift->headers->referer(@_) }
sub user_agent       { shift->headers->user_agent(@_) }

=head1 NAME

Catalyst::Request - Catalyst Request Class

=head1 SYNOPSIS


    $req = $c->request;
    $req->action;
    $req->address;
    $req->args;
    $req->arguments;
    $req->base;
    $req->body;
    $req->body_parameters;
    $req->content_encoding;
    $req->content_length;
    $req->content_type;
    $req->cookie;
    $req->cookies;
    $req->header;
    $req->headers;
    $req->hostname;
    $req->input;
    $req->match;
    $req->method;
    $req->param;
    $req->params;
    $req->parameters;
    $req->path;
    $req->protocol;
    $req->query_parameters;
    $req->read;
    $req->referer;
    $req->secure;
    $req->snippets;
    $req->upload;
    $req->uploads;
    $req->uri;
    $req->user;
    $req->user_agent;

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

=item $req->body

Contains the message body of the request unless Content-Type is
C<application/x-www-form-urlencoded> or C<multipart/form-data>.

    print $c->request->body

=cut

sub body {
    my ( $self, $body ) = @_;
    $self->{_context}->prepare_body;
    return $self->{_body}->body;
}

=item $req->body_parameters

Returns a reference to a hash containing body parameters. Values can
be either a scalar or an arrayref containing scalars.

    print $c->request->body_parameters->{field};
    print $c->request->body_parameters->{field}->[0];
    
=item $req->body_params

An alias for body_parameters.

=cut

sub body_parameters {
    my ( $self, $params ) = @_;
    $self->{_context}->prepare_body;
    $self->{body_parameters} = $params if $params;
    return $self->{body_parameters};
}

=item $req->content_encoding

Shortcut to $req->headers->content_encoding

=item $req->content_length

Shortcut to $req->headers->content_length

=item $req->content_type

Shortcut to $req->headers->content_type

=item $req->cookie

A convenient method to $req->cookies.

    $cookie  = $c->request->cookie('name');
    @cookies = $c->request->cookie;

=cut

sub cookie {
    my $self = shift;

    if ( @_ == 0 ) {
        return keys %{ $self->cookies };
    }

    if ( @_ == 1 ) {

        my $name = shift;

        unless ( exists $self->cookies->{$name} ) {
            return undef;
        }

        return $self->cookies->{$name};
    }
}

=item $req->cookies

Returns a reference to a hash containing the cookies.

    print $c->request->cookies->{mycookie}->value;

=item $req->header

Shortcut to $req->headers->header

=item $req->headers

Returns an L<HTTP::Headers> object containing the headers.

    print $c->request->headers->header('X-Catalyst');

=item $req->hostname

Lookup the current users DNS hostname.

    print $c->request->hostname
    
=cut

sub hostname {
    my $self = shift;

    if ( @_ == 0 && not $self->{hostname} ) {
        $self->{hostname} =
          gethostbyaddr( inet_aton( $self->address ), AF_INET );
    }

    if ( @_ == 1 ) {
        $self->{hostname} = shift;
    }

    return $self->{hostname};
}

=item $req->input

Shortcut for $req->body.

=item $req->match

This contains the matching part of a regexp action. Otherwise
it returns the same as 'action'.

    print $c->request->match;

=item $req->method

Contains the request method (C<GET>, C<POST>, C<HEAD>, etc).

    print $c->request->method;

=item $req->param

Get request parameters with a CGI.pm-compatible param method. This 
is a method for accessing parameters in $c->req->parameters.

    $value  = $c->request->param('foo');
    @values = $c->request->param('foo');
    @params = $c->request->param;

=cut

sub param {
    my $self = shift;

    if ( @_ == 0 ) {
        return keys %{ $self->parameters };
    }

    if ( @_ == 1 ) {

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

    if ( @_ > 1 ) {

        while ( my ( $field, $value ) = splice( @_, 0, 2 ) ) {

            next unless defined $field;

            if ( exists $self->parameters->{$field} ) {
                for ( $self->parameters->{$field} ) {
                    $_ = [$_] unless ref($_) eq "ARRAY";
                    push( @$_, $value );
                }
            }
            else {
                $self->parameters->{$field} = $value;
            }
        }
    }
}

=item $req->params

Shortcut for $req->parameters.

=item $req->parameters

Returns a reference to a hash containing parameters. Values can
be either a scalar or an arrayref containing scalars.

    print $c->request->parameters->{field};
    print $c->request->parameters->{field}->[0];

=cut

sub parameters {
    my ( $self, $params ) = @_;
    $self->{_context}->prepare_body;
    $self->{parameters} = $params if $params;
    return $self->{parameters};
}

=item $req->path

Contains the path.

    print $c->request->path;

=item $req->path_info

alias for path, added for compability with L<CGI>

=cut

sub path {
    my ( $self, $params ) = @_;

    if ($params) {
        $self->uri->path($params);
    }

    my $path     = $self->uri->path;
    my $location = $self->base->path;
    $path =~ s/^(\Q$location\E)?//;
    $path =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
    $path =~ s/^\///;

    return $path;
}

=item $req->protocol

Contains the protocol.

=item $req->query_parameters

Returns a reference to a hash containing query parameters. Values can
be either a scalar or an arrayref containing scalars.

    print $c->request->query_parameters->{field};
    print $c->request->query_parameters->{field}->[0];
    
=item $req->read( [$maxlength] )

Read a chunk of data from the request body.  This method is designed to be
used in a while loop, reading $maxlength bytes on every call.  $maxlength
defaults to the size of the request if not specified.

You have to set MyApp->config->{parse_on_demand} to use this directly.

=cut

sub read { shift->{_context}->read(@_); }

=item $req->referer

Shortcut to $req->headers->referer. Referring page.

=item $req->secure

Contains a boolean denoting whether the communication is secure.

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

    if ( @_ == 1 ) {

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

    if ( @_ > 1 ) {

        while ( my ( $field, $upload ) = splice( @_, 0, 2 ) ) {

            if ( exists $self->uploads->{$field} ) {
                for ( $self->uploads->{$field} ) {
                    $_ = [$_] unless ref($_) eq "ARRAY";
                    push( @$_, $upload );
                }
            }
            else {
                $self->uploads->{$field} = $upload;
            }
        }
    }
}

=item $req->uploads

Returns a reference to a hash containing uploads. Values can be either a
hashref or a arrayref containing C<Catalyst::Request::Upload> objects.

    my $upload = $c->request->uploads->{field};
    my $upload = $c->request->uploads->{field}->[0];

=cut

sub uploads {
    my ( $self, $uploads ) = @_;
    $self->{_context}->prepare_body;
    $self->{uploads} = $uploads if $uploads;
    return $self->{uploads};
}

=item $req->uri

Returns a URI object for the request.

=item $req->user

Contains the user name of user if authentication check was successful.

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
