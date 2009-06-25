package Catalyst::ScriptRunner;
use Moose;

sub run {
    my ($self, $class, $scriptclass) = @_;
    my $classtoload = "${class}::Script::$scriptclass"; 
    Class::MOP::load_class($classtoload); 
    $classtoload->new_with_options->run;
}
1;
