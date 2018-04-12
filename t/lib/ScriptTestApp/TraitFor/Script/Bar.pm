package ScriptTestApp::TraitFor::Script::Bar;
use Moose::Role;
use namespace::clean -except => [ 'meta' ];

around run => sub {
    my ($orig, $self, @args) = @_;
    return $self->$orig(@args) . '23';
};

1;
