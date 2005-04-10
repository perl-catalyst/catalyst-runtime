package TestApp::View::Dump;

use strict;
use base qw[Catalyst::Base];

use Data::Dumper ();

sub dump {
    my ( $self, $reference ) = @_;

    return unless $reference;

    my $dumper = Data::Dumper->new( [ $reference ] );
    $dumper->Indent(1);
    $dumper->Purity(1);
    $dumper->Useqq(0);
    $dumper->Deepcopy(1);
    $dumper->Quotekeys(0);
    $dumper->Terse(1);

    return $dumper->Dump;
}

sub process {
    my ( $self, $c, $reference ) = @_;

    if ( my $output = $self->dump( $reference || $c->stash->{dump} || $c->stash ) ) {

	    $c->res->headers->content_type('text/plain');
	    $c->res->output($output);
       return 1;
    }

    return 0;
}

1;
