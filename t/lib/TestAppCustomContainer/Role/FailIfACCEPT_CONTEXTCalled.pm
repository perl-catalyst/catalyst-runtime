package TestAppCustomContainer::Role::FailIfACCEPT_CONTEXTCalled;
use Moose::Role;
use Test::More;

sub ACCEPT_CONTEXT {}
before ACCEPT_CONTEXT => sub {
    my ($self, $ctx, @args) = @_;
    fail("ACCEPT_CONTEXT called for $self");
};

1;
