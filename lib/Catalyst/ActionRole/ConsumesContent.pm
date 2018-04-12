package Catalyst::ActionRole::ConsumesContent;

use Moose::Role;

requires 'match', 'match_captures', 'list_extra_info';

has allowed_content_types => (
  is=>'ro',
  required=>1,
  lazy=>1,
  isa=>'ArrayRef',
  builder=>'_build_allowed_content_types');

has normalized => (
  is=>'ro',
  required=>1,
  lazy=>1,
  isa=>'HashRef',
  builder=>'_build_normalized');


sub _build_normalized {
  return +{
    JSON => 'application/json',
    JS => 'application/javascript',
    PERL => 'application/perl',
    HTML => 'text/html',
    XML => 'text/XML',
    Plain => 'text/plain',
    UrlEncoded => 'application/x-www-form-urlencoded',
    Multipart => 'multipart/form-data',
    HTMLForm => ['application/x-www-form-urlencoded','multipart/form-data'],
  };
}

sub _build_allowed_content_types {
    my $self = shift;
    my @proto = map {split ',', $_ } @{$self->attributes->{Consumes}};
    my @converted = map {
      if(my $normalized = $self->normalized->{$_}) {
        ref $normalized ? @$normalized : ($normalized);
      } else {
        $_;
      }
    } @proto;

    return \@converted;
}

around ['match','match_captures'] => sub {
    my ($orig, $self, $ctx, @args) = @_;
    if(my $content_type = $ctx->req->content_type) {
        return 0 unless $self->can_consume($content_type);
    }
    return $self->$orig($ctx, @args);
};

sub can_consume {
    my ($self, $request_content_type) = @_;
    my @matches = grep { lc($_) eq lc($request_content_type) }
      @{$self->allowed_content_types};
    return @matches ? 1:0;
}

around 'list_extra_info' => sub {
  my ($orig, $self, @args) = @_;
  return {
    %{ $self->$orig(@args) },
    CONSUMES => $self->allowed_content_types,
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
