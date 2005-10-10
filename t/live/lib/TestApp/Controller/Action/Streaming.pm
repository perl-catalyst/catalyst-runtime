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

1;
