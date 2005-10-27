package TestApp::View::Dump;

use strict;
use base 'Catalyst::Base';

use Data::Dumper ();
use Scalar::Util qw(weaken);

sub dump {
    my ( $self, $reference ) = @_;

    return unless $reference;

    my $dumper = Data::Dumper->new( [$reference] );
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

    # Force processing of on-demand data
    $c->prepare_body;

    # Remove context from reference if needed
    my $context = delete $reference->{_context};

    # Remove body from reference if needed
    my $body = delete $reference->{_body};

    if ( my $output =
        $self->dump( $reference || $c->stash->{dump} || $c->stash ) )
    {

        $c->res->headers->content_type('text/plain');
        $c->res->output($output);

        # Repair context
        $reference->{_context} = $context;
        weaken( $reference->{_context} );

        # Repair body
        $reference->{_body} = $body;

        return 1;
    }

    return 0;
}

1;
