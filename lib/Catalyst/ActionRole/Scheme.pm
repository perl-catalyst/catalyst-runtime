package Catalyst::ActionRole::Scheme;

use Moose::Role;

requires 'match', 'match_captures', 'list_extra_info';

around ['match','match_captures'] => sub {
    my ($orig, $self, $ctx, @args) = @_;
    my $request_scheme = lc($ctx->req->env->{'psgi.url_scheme'});
    my $match_scheme = lc($self->scheme||'');

    return $request_scheme eq $match_scheme ? $self->$orig($ctx, @args) : 0;
};

around 'list_extra_info' => sub {
  my ($orig, $self, @args) = @_;
  return {
    %{ $self->$orig(@args) }, 
    Scheme => $self->attributes->{Scheme}[0]||'',
  };
};

1;

=head1 NAME

Catalyst::ActionRole::ConsumesContent - Match on HTTP Request Content-Type

=head1 SYNOPSIS

    package MyApp::Web::Controller::MyController;

    use base 'Catalyst::Controller';

    sub start : POST Chained('/') CaptureArg(0) { ... }

      sub is_json       : Chained('start') Consumes('application/json') { ... }
      sub is_urlencoded : Chained('start') Consumes('application/x-www-form-urlencoded') { ... }
      sub is_multipart  : Chained('start') Consumes('multipart/form-data') { ... }
      
      ## Alternatively, for common types...

      sub is_json       : Chained('start') Consume(JSON) { ... }
      sub is_urlencoded : Chained('start') Consumes(UrlEncoded) { ... }
      sub is_multipart  : Chained('start') Consumes(Multipart) { ... }

      ## Or allow more than one type
      
      sub is_more_than_one
        : Chained('start')
        : Consumes('application/x-www-form-urlencoded')
        : Consumes('multipart/form-data')
      {
        ## ... 
      }

      1;

=head1 DESCRIPTION

This is an action role that lets your L<Catalyst::Action> match on the content
type of the incoming request.  

Generally when there's a PUT or POST request, there's a request content body
with a matching MIME content type.  Commonly this will be one of the types
used with classic HTML forms ('application/x-www-form-urlencoded' for example)
but there's nothing stopping you specifying any valid content type.

For matching purposes, we match strings but the casing is insensitive.

=head1 REQUIRES

This role requires the following methods in the consuming class.

=head2 match

=head2 match_captures

Returns 1 if the action matches the existing request and zero if not.

=head1 METHODS

This role defines the following methods

=head2 match

=head2 match_captures

Around method modifier that return 1 if the request content type matches one of the
allowed content types (see L</http_methods>) and zero otherwise.

=head2 allowed_content_types

An array of strings that are the allowed content types for matching this action.

=head2 can_consume

Boolean.  Does the current request match content type with what this actionrole
can consume?

=head2 list_extra_info

Add the accepted content type to the debug screen.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
