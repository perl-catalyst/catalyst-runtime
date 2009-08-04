package Catalyst::Script::Test;
use Moose;
use Pod::Usage;
use FindBin;
use lib "$FindBin::Bin/../lib";
with 'MooseX::Getopt';
use MooseX::Types::Moose qw/Str Bool/;
use namespace::autoclean;

#extends qw(MooseX::App::Cmd);

has _app => (
    reader   => 'app',
    init_arg => 'app',
    traits => [qw(NoGetopt)],
    isa => Str,
    is => 'ro',
);

has help => (
    traits => [qw(Getopt)],
    cmd_aliases => 'h',
    isa => Bool,
    is => 'ro',
    documentation => qq{ display this help and exits },
);


sub run {
    my $self = shift;

    Class::MOP::load_class("Catalyst::Test");
    Catalyst::Test->import($self->app);

    pod2usage(1) if ( $self->help || !$ARGV[1] );
    print request($ARGV[1])->content  . "\n";

}


__PACKAGE__->meta->make_immutable;
1;
