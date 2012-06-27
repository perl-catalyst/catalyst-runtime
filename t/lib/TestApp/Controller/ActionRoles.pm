package TestApp::Controller::ActionRoles;

use Moose;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(
    action_roles => ['~Kooh'],
    action_args => {
        frew => { boo => 'hello' },
    },
);

sub foo  : Local Does('Moo')  {}
sub bar  : Local Does('~Moo') {}
sub baz  : Local Does('+Moo') {}
sub quux : Local Does('Zoo')  {}

sub corge : Local Does('Moo') ActionClass('TestAfter') {
    my ($self, $ctx) = @_;
    $ctx->stash(after_message => 'moo');
}

sub frew : Local Does('Boo')  {
    my ($self, $ctx) = @_;
    my $boo = $ctx->stash->{action_boo};
    $ctx->response->body($boo);
}

1;
