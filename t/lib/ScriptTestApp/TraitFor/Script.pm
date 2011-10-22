package ScriptTestApp::TraitFor::Script;
use Moose::Role;
use namespace::autoclean;

around run => sub {
    my ($orig, $self, @args) = @_;
    return 'moo' . $self->$orig(@args);
};

1;
