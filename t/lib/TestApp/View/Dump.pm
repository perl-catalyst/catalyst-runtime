package TestApp::View::Dump;

use strict;
use base 'Catalyst::View';

use Data::Dumper ();
use Scalar::Util qw(blessed weaken);

sub dump {
    my ( $self, $reference, $purity ) = @_;

    return unless $reference;

    $purity = defined $purity ? $purity : 1;

    my $dumper = Data::Dumper->new( [$reference] );
    $dumper->Indent(1);
    $dumper->Purity($purity);
    $dumper->Useqq(0);
    $dumper->Deepcopy(1);
    $dumper->Quotekeys(1);
    $dumper->Terse(1);

    local $SIG{ __WARN__ } = sub { warn unless $_[ 0 ] =~ m{dummy} };
    return $dumper->Dump;
}

sub process {
    my ( $self, $c, $reference, $purity ) = @_;

    # Force processing of on-demand data
    $c->prepare_body;

    # Remove body from reference if needed
    $reference->{__body_type} = blessed $reference->body
        if (blessed $reference->{_body});
    my $body = delete $reference->{_body};

    # Remove context from reference if needed
    my $context = delete $reference->{_context};

    if ( my $output =
        $self->dump( $reference, $purity ) )
    {

        $c->res->headers->content_type('text/plain');
        $c->res->output($output);

        if ($context) {
            # Repair context
            $reference->{_context} = $context;
            weaken( $reference->{_context} );
        }

        if ($body) {
            # Repair body
            delete $reference->{__body_type};
            $reference->{_body} = $body;
        }

        return 1;
    }

    return 0;
}

1;
