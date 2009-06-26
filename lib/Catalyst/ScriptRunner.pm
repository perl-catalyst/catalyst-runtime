package Catalyst::ScriptRunner;
use Moose;

sub run {
    my ($self, $class, $scriptclass) = @_;
    my $classtoload = "${class}::Script::$scriptclass"; 
    
    if ( Class::MOP::load_class($classtoload) ) {  
        $classtoload->new_with_options->run;
    } else {
        $classtoload = "Catalyst::Script::$scriptclass";
        $classtoload->new_with_options->run;
    }
}
1;
