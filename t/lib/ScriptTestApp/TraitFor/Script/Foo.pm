package ScriptTestApp::TraitFor::Script::Foo;
use Moose::Role;
use namespace::autoclean;

around run => sub {
    my ($orig, $self, @args) = @_;
    return $self->$orig(@args) . '42';
};

1;
