package ScriptTestApp::TraitFor::Script;
use Moose::Role;
use namespace::clean -except => [ 'meta' ];

around run => sub {
    my ($orig, $self, @args) = @_;
    return 'moo' . $self->$orig(@args);
};

1;
