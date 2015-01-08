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

Catalyst::ActionRole::Scheme - Match on HTTP Request Scheme

=head1 SYNOPSIS

    package MyApp::Web::Controller::MyController;

    use base 'Catalyst::Controller';

    sub is_http :Path(scheme) Scheme(http) Args(0) {
      my ($self, $c) = @_;
      Test::More::is $c->action->scheme, 'http';
      $c->response->body("is_http");
    }

    sub is_https :Path(scheme) Scheme(https) Args(0)  {
      my ($self, $c) = @_;
      Test::More::is $c->action->scheme, 'https';
      $c->response->body("is_https");
    }

    1;

=head1 DESCRIPTION

This is an action role that lets your L<Catalyst::Action> match on the scheme
type of the request.  Typically this is C<http> or C<https> but other common
schemes that L<Catalyst> can handle include C<ws> and C<wss> (web socket and web
socket secure).

This also ensures that if you use C<uri_for> on an action that specifies a
match scheme, that the generated L<URI> object sets its scheme to that automatically
(rather than the scheme of the current request object, which is and remains the
default behavior.)

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

Around method modifier that return 1 if the scheme matches

=head2 list_extra_info

Add the scheme declaration if present to the debug screen.

=head1 AUTHORS

Catalyst Contributors, see L<Catalyst>

=head1 COPYRIGHT

See L<Catalyst>

=cut
