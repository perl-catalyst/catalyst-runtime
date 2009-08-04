package Catalyst::Script::Deploy;

use Moose;
use namespace::autoclean;

with 'MooseX::Getopt';
use MooseX::Types::Moose qw/Str/;
use Config::General;
use FindBin;
use lib "$FindBin::Bin/../lib";

#extends qw(MooseX::App::Cmd);


has _app => (
    reader   => 'app',
    init_arg => 'app',
    traits => [qw(NoGetopt)],
    isa => Str,
    is => 'ro',
);

has conf => ( 
    is  => 'ro', 
    isa => Str,
    traits => [qw(Getopt)],
    cmd_alias => 'c',
    documentation => qq{ specify a configuration file to read from }
);

sub usage {

   print "usage: perl script/myapp_deploy_schema.pl myapp.conf\n";
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

__PACKAGE__->meta->make_immutable;

1;

