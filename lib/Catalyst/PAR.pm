package Catalyst::PAR;

use strict;
use base 'Class::Accessor::Fast';
use FindBin;
use IO::File;
use File::Spec;
use File::Find;
require Catalyst;

=head1 NAME

Catalyst::PAR - Package Catalyst Applications

=head1 SYNOPSIS

See L<Catalyst>

=head1 DESCRIPTION

Package Catalyst Applications.

=head1 METHODS

=over 4

=item $self->package( $par, $engine )

=cut

sub package {
    my ( $self, $options ) = @_;

    my $par    = $options->{par}    || 'application.par';
    my $engine = $options->{engine} || 'CGI';

    # Check for PAR
    eval "use PAR ()";
    die "Please install PAR" if $@;
    eval "use PAR::Packer ()";
    die "Please install PAR::Packer" if $@;
    eval "use App::Packer::PAR ()";
    die "Please install App::Packer::PAR" if $@;
    eval "use Module::ScanDeps ()";
    die "Please install Module::ScanDeps" if $@;

    chdir File::Spec->catdir( $FindBin::Bin, '..' );

    # Find additional files
    my @files;
    finddepth(
        sub {
            my $name = $File::Find::name;
            return if $name =~ /^\W*lib/;
            return if $name =~ /\.par$/;
            return if $name !~ /\w+/;
            warn "$name\n";
            push @files, $name;
        },
        '.'
    );

    my $par_test = File::Spec->catfile( $FindBin::Bin, '..', 'par_test.pl' );
    unlink $par_test;

    my $class    = $options->{class};
    my $tmp_file = IO::File->new("> $par_test");
    print $tmp_file <<"EOF";
BEGIN { \$ENV{CATALYST_ENGINE} = '$engine' };
use FindBin;
use lib 'lib';
use $class;
EOF
    $tmp_file->close;

    # Create package
    my %opt = ( 'x' => 1, 'n' => 0, 'o' => $par, 'a' => [@files] );
    App::Packer::PAR->new(
        frontend  => 'Module::ScanDeps',
        backend   => 'PAR::Packer',
        frontopts => \%opt,
        backopts  => \%opt,
        args      => ['par_test.pl'],
    )->go;

    unlink $par_test;
}

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
