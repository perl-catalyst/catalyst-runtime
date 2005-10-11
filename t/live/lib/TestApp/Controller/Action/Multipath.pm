package TestApp::Controller::Action::Multipath;

use strict;
use base 'TestApp::Controller::Action';

sub multipath : Local : Global : Path('/multipath1') : Path('multipath2') {
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
