package Catalyst::Script::Create;
use Moose;
use MooseX::Types::Moose qw/Bool Str/;
use namespace::autoclean;

with 'Catalyst::ScriptRole';

has force => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'nonew',
    isa           => Bool,
    is            => 'ro',
    documentation => 'Force new scripts',
);

has debug => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'd',
    isa           => Bool,
    is            => 'ro',
    documentation => 'Force debug mode',
);

has mechanize => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'mech',
    isa           => Bool,
    is            => 'ro',
    documentation => 'use WWW::Mechanize',
);

has helper_class => (
    isa     => Str,
    is      => 'ro',
    builder => '_build_helper_class',
);

sub _build_helper_class { 'Catalyst::Helper' }

sub run {
    my ($self) = @_;

    $self->_getopt_full_usage if !$self->ARGV->[0];

    my $helper_class = $self->helper_class;
    Class::MOP::load_class($helper_class);
    my $helper = $helper_class->new( { '.newfiles' => !$self->force, mech => $self->mechanize } );

    $self->_getopt_full_usage unless $helper->mk_component( $self->application_name, @{$self->extra_argv} );

}

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Catalyst::Script::Create - Create a new Catalyst Component

=head1 SYNOPSIS

 myapp_create.pl [options] model|view|controller name [helper] [options]

 Options:
   --force        don't create a .new file where a file to be created exists
   --mechanize    use Test::WWW::Mechanize::Catalyst for tests if available
   --help         display this help and exits

 Examples:
   myapp_create.pl controller My::Controller
   myapp_create.pl controller My::Controller BindLex
   myapp_create.pl --mechanize controller My::Controller
   myapp_create.pl view My::View
   myapp_create.pl view MyView TT
   myapp_create.pl view TT TT
   myapp_create.pl model My::Model
   myapp_create.pl model SomeDB DBIC::Schema MyApp::Schema create=dynamic\
   dbi:SQLite:/tmp/my.db
   myapp_create.pl model AnotherDB DBIC::Schema MyApp::Schema create=static\
   dbi:Pg:dbname=foo root 4321

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Create a new Catalyst Component.

Existing component files are not overwritten.  If any of the component files
to be created already exist the file will be written with a '.new' suffix.
This behavior can be suppressed with the C<--force> option.

=head1 SEE ALSO

L<Catalyst::ScriptRunner>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

