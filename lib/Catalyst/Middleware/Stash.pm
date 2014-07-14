use strict;
use warnings;

package Catalyst::Middleware::Stash;

use base 'Plack::Middleware';
use Exporter 'import';
use Scalar::Util 'blessed';
use Carp 'croak';

our @EXPORT_OK = qw(stash get_stash);

sub PSGI_KEY { 'Catalyst.Stash.v1' };

sub get_stash { return shift->{PSGI_KEY} }

sub generate_stash_closure {
  my $stash = shift || +{};
  return sub {
    if(@_) {
      my $new_stash = @_ > 1 ? {@_} : $_[0];
      croak('stash takes a hash or hashref')
        unless ref $new_stash;
      foreach my $key ( keys %$new_stash ) {
        $stash->{$key} = $new_stash->{$key};
      }
    }
    $stash;
  };
}

sub _init_stash {
  my ($self, $env) = @_;
  return $env->{PSGI_KEY} ||=
    generate_stash_closure;
}

sub stash {
  my ($host, @args) = @_;
  return get_stash($host->env)->(@args);
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

We store a coderef under the C<PSGI_KEY> which can be dereferenced with
key values or nothing to access the underly hashref.

=head1 SUBROUTINES

This class defines the following subroutines.

=head2 PSGI_KEY

Returns the hash key where we store the stash

=head2 get_stash

Get the stash out of the C<$env>

=head2 stash

Exportable subroutine.

Given an object with a method C<env> get or set stash values, either
as a method or via hashref modification.  This stash is automatically
reset for each request (it is not persistent or shared across connected
clients.  Stash key / value are stored in memory.

    Catalyst::Middleware::Stash 'stash';

    $c->stash->{foo} = $bar;
    $c->stash( { moose => 'majestic', qux => 0 } );
    $c->stash( bar => 1, gorch => 2 ); # equivalent to passing a hashref

=head2 generate_stash_closure

Creates the closure which is stored in the L<PSGI> environment.

=head1 METHODS

This class defines the following methods.

=head2 call

Used by plack to call the middleware

=cut

1;
