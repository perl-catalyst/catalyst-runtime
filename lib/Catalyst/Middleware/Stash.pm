package ## Hide from pause
  Catalyst::Middleware::Stash;

# Please don't use this, this is likely to go away before stable version is
# released.  Ideally this could be a stand alone distribution.
# 

use strict;
use warnings;
use base 'Plack::Middleware';

sub PSGI_KEY { 'Catalyst.Stash.v1' };

sub _init_stash {
  my ($self, $env) = @_;
  $env->{&PSGI_KEY} = bless +{}, 'Catalyst::Stash';
}

sub get {
  my ($class, $env) = @_;
  return $env->{&PSGI_KEY};
}

sub call {
  my ($self, $env) = @_;
  $self->_init_stash($env);
  return $self->app->($env);
}

=head1 TITLE

Catalyst::Middleware::Stash - The Catalyst stash - in middleware

=head1 DESCRIPTION

We've moved the L<Catalyst> stash to middleware.  Please don't use this
directly since it is likely to move off the Catalyst namespace into a stand
alone distribution

=head1 METHODS

This class defines the following methods

=head2 PSGI_KEY

Returns the hash key where we store the stash

=head2 get 

Get the stash out of the C<$env>

=head2 call

Used by plack to call the middleware

=cut

1;
