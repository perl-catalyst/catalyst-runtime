package TestApp::View::Dump::Env;

use strict;
use base qw[TestApp::View::Dump];

sub process {
    my ( $self, $c ) = @_;
    my $env = $c->stash->{env};
    return $self->SUPER::process($c, {
        map { ($_ => $env->{$_}) }
        grep { $_ ne 'psgi.input' }
        keys %{ $env },
    });
}

## We override Data::Dumper here since its not reliably outputting
## something that is roundtrip-able.

sub dump {
    my ( $self, $reference ) = @_;
    use Data::Dump ();
    return Data::Dump::dump($reference);
}

1;

