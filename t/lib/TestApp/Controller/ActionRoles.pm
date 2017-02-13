package TestApp::Controller::ActionRoles;

use Moose;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(
    action_roles => ['~Kooh'],
    action_args => {
        frew => { boo => 'hello' },
    },
);

sub foo  : Local Does('Guff')  {}
sub bar  : Local Does('~Guff') {}
sub baz  : Local Does('+Guff') {}
sub quux : Local Does('Zoo')  {}

sub corge : Local Does('Guff') ActionClass('TestAfter') {
    my ($self, $ctx) = @_;
    $ctx->stash(after_message => 'moo');
}

sub frew : Local Does('Boo')  {
    my ($self, $ctx) = @_;
    my $boo = $ctx->stash->{action_boo};
    $ctx->response->body($boo);
}

1;
