use strict;
use warnings;

package Catalyst::Middleware::Stash;

use base 'Plack::Middleware';
use Exporter 'import';
use Carp 'croak';

our @EXPORT_OK = qw(stash get_stash);

sub PSGI_KEY () { 'Catalyst.Stash.v2' }

sub get_stash {
  my $env = shift;
  return $env->{+PSGI_KEY} ||
   croak "You requested a stash, but one does not exist.";
}

sub stash {
  my ($host, @args) = @_;
  return get_stash($host->env)
    ->(@args);
}

sub _create_stash {
  my $self = shift;
  my $stash = shift || +{};
  return sub {
    if(@_) {
      my $new_stash = @_ > 1 ? {@_} : $_[0];
      croak('stash takes a hash or hashref')
        unless ref $new_stash;
      foreach my $key (keys %$new_stash) {
        $stash->{$key} = $new_stash->{$key};
      }
    }
    $stash;
  };
}

sub call {
  my ($self, $env) = @_;
  $env->{+PSGI_KEY} = $self->_create_stash 
    unless exists($env->{+PSGI_KEY});

  return $self->app->($env);
}

=head1 NAME

Catalyst::Middleware::Stash - The Catalyst stash - in middleware

=head1 DESCRIPTION

We've moved the L<Catalyst> stash to middleware.  Please don't use this
directly since it is likely to move off the Catalyst namespace into a stand
alone distribution

We store a coderef under the C<PSGI_KEY> which can be dereferenced with
key values or nothing to access the underlying hashref.

Anything placed into the stash will be available in the stash of any 'mounted'
Catalyst applications.  A mounted Catalyst application may set the stash and
'pass back' information to the parent application.  Non Catalyst applications
may use this middleware to access and set stash values.

Please note I highly recommend having a stronger interface than a stash key
between applications.

For more information the current test case t/middleware-stash.t is the best
documentation.

=head1 SUBROUTINES

This class defines the following subroutines.

=head2 PSGI_KEY

Returns the hash key where we store the stash.  You should not assume
the string value here will never change!  Also, its better to use
L</get_stash> or L</stash>.

=head2 get_stash

Expect: $psgi_env.

Exportable subroutine.

Get the stash out of the C<$env>.

=head2 stash

Expects: An object that does C<env> and arguments

Exportable subroutine.

Given an object with a method C<env> get or set stash values, either
as a method or via hashref modification.  This stash is automatically
reset for each request (it is not persistent or shared across connected
clients.  Stash key / value are stored in memory.

    use Plack::Request;
    use Catalyst::Middleware::Stash 'stash';

    my $app = sub {
      my $env = shift;
      my $req = Plack::Request->new($env);
      my $stashed = $req->stash->{in_the_stash};  # Assume the stash was previously populated.

      return [200, ['Content-Type' => 'text/plain'],
        ["I found $stashed in the stash!"]];
    };

If the stash does not yet exist, an exception is thrown.

=head1 METHODS

This class defines the following methods.

=head2 call

Used by plack to call the middleware

=cut

1;
