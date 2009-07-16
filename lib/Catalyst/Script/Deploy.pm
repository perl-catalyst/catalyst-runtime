package Catalyst::Script::Deploy;

use Moose;
use namespace::autoclean;

with 'MooseX::Getopt';
use Config::General;
use FindBin;
use lib "$FindBin::Bin/../lib";

has _app => (
    reader   => 'app',
    init_arg => 'app',
    traits => [qw(NoGetopt)],
    isa => 'Str',
    is => 'ro',
);

has conf => ( 
    is  => 'ro', 
    isa => 'Str',
    traits => [qw(Getopt)],
    cmd_alias => 'c',
);





sub usage {

   print "usage: perl script/boyosplace_deploy_schema.pl boyosplace.conf\n";
   exit;

}

sub run {
    my ($self) = shift;

    $self->usage if $self->help;

    my $app = $self->app;
    Class::MOP::load_class($app);
    Class::MOP::load_class("$app::Schema");
    
    my %hash = $conf->getall;

    my $schema = $app::Schema->connect(
        $hash{"Model::$schema_name"}{connect_info}[0], 
        $hash{"Model::$schema_name"}{connect_info}[1], 
        $hash{"Model::$schema_name"}{connect_info}[2]
    );
    $schema->deploy( { add_drop_tables => 1 } );


}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

