package TestApp::Controller::Action::Streaming;

use strict;
use base 'TestApp::Controller::Action';

sub streaming : Global {
    my ( $self, $c ) = @_;
    for my $line ( split "\n", <<'EOF' ) {
foo
bar
baz
EOF
        $c->res->write("$line\n");
    }
}

sub body : Local {
    my ( $self, $c ) = @_;
    
    my $file = "$FindBin::Bin/../../../../01use.t";
    my $fh = IO::File->new( $file, 'r' );
    if ( defined $fh ) {
        $c->res->body( $fh );
    }
    else {
        $c->res->body( "Unable to read $file" );
    }
}

1;
