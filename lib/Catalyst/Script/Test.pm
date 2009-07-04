package Catalyst::Script::Test;
use Moose;
use Pod::Usage;
use FindBin;
use lib "$FindBin::Bin/../lib";
with 'MooseX::Getopt';
use namespace::autoclean -except => [ qw(meta) ];

has app  => ( isa => 'Str',    is => 'ro', required => 1 );
has help => ( isa => 'Bool',   is => 'ro', required => 0, default => sub { 0 } );


sub run {
    my $self = shift;

    Class::MOP::load_class("Catalyst::Test");
    Catalyst::Test->import($self->app);
    
    pod2usage(1) if ( $self->help || !$ARGV[1] );
    print request($ARGV[1])->content  . "\n";
        
}

1;
