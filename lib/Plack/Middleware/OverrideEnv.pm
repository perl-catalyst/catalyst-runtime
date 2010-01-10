package Plack::Middleware::OverrideEnv;

use strict;
use warnings;
use parent 'Plack::Middleware';

use Plack::Util::Accessor qw(env_override);

sub call {
    my ($self, $env) = @_;
    return $self->app->({ %{ $env }, %{ $self->env_override || {} } });
}

1;
