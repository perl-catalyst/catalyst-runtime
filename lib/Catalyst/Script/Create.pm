package Catalyst::Script::Create;
use Moose;
use Pod::Usage;
use Catalyst::Helper;
use MooseX::Types::Moose qw/Str Bool/;
use namespace::autoclean;

with "MooseX::Getopt";
#extends qw(MooseX::App::Cmd);


has _app => (
    reader   => 'app',
    init_arg => 'app',
    traits => [qw(NoGetopt)],
    isa => Str,
    is => 'ro',
);

has force => (
    traits => [qw(Getopt)],
    cmd_aliases => 'nonew',
    isa => Bool,
    is => 'ro',
    documentation => qq{ force new scripts }
);

has help => (
    traits => [qw(Getopt)],
    cmd_aliases => 'h',
    isa => Bool,
    is => 'ro',
    documentation => qq{ display this help and exits },
);

has debug => (
    traits => [qw(Getopt)],
    cmd_aliases => 'd',
    isa => Bool,
    is => 'ro',
    documentation => qq{ force debug mode }
);

has mechanize => (
    traits => [qw(Getopt)],
    cmd_aliases => 'mech',
    isa => Bool,
    is => 'ro',
    documentation => qq{ use WWW::Mechanize },
);

sub run {
    my ($self) = @_;


    pod2usage(1) if ( $self->help || !$ARGV[0] );

    my $helper = Catalyst::Helper->new( { '.newfiles' => !$self->force, mech => $self->mech } );

    pod2usage(1) unless $helper->mk_component( $self->app, @ARGV );

}

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

boyosplace_create.pl - Create a new Catalyst Component

=head1 SYNOPSIS

boyosplace_create.pl [options] model|view|controller name [helper] [options]

 Options:
   -force        don't create a .new file where a file to be created exists
   -mechanize    use Test::WWW::Mechanize::Catalyst for tests if available
   -help         display this help and exits

 Examples:
   boyosplace_create.pl controller My::Controller
   boyosplace_create.pl controller My::Controller BindLex
   boyosplace_create.pl -mechanize controller My::Controller
   boyosplace_create.pl view My::View
   boyosplace_create.pl view MyView TT
   boyosplace_create.pl view TT TT
   boyosplace_create.pl model My::Model
   boyosplace_create.pl model SomeDB DBIC::Schema MyApp::Schema create=dynamic\
   dbi:SQLite:/tmp/my.db
   boyosplace_create.pl model AnotherDB DBIC::Schema MyApp::Schema create=static\
   dbi:Pg:dbname=foo root 4321

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Create a new Catalyst Component.

Existing component files are not overwritten.  If any of the component files
to be created already exist the file will be written with a '.new' suffix.
This behavior can be suppressed with the C<-force> option.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
