package Catalyst::ScriptRunner;
use Moose;
extends qw(MooseX::App::Cmd::Command);


sub run {
    my ($self, $class, $scriptclass) = @_;
    my $classtoload = "${class}::Script::$scriptclass";

    # FIXME - Error handling / reporting
    if ( eval { Class::MOP::load_class($classtoload) } ) {
    } else {
        $classtoload = "Catalyst::Script::$scriptclass";
        Class::MOP::load_class($classtoload);
    }
    $classtoload->new_with_options( app => $class )->run;
}
1;
