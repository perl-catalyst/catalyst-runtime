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

=item $self->package(\%options)

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
            return if $name =~ /^\W*blib/;
            return if $name =~ /^\W*_build/;
            return if $name =~ /\.par$/;
            return if $name !~ /\w+/;
            push @files, $name;
        },
        '.'
    );

    my $par_test = File::Spec->catfile( $FindBin::Bin, '..', 'par_test.pl' );
    unlink $par_test;

    my $classes = '';
    for my $req ( split ',', $options->{classes} ) {
        $classes .= "require $req;\n";
    }
    my $version  = $Catalyst::VERSION;
    my $class    = $options->{class};
    my $tmp_file = IO::File->new("> $par_test");
    print $tmp_file <<"EOF";
die "$class on Catalyst $version\n" if \$0 !~ /par_test.pl\.\\w+\$/;
BEGIN { \$ENV{CATALYST_ENGINE} = '$engine' };
use lib 'lib';
require $class;
import $class;
$classes
EOF
    $tmp_file->close;

    # Create package
    local $SIG{__WARN__} = sub { };
    open my $olderr, '>&STDERR';
    open STDERR, '>', File::Spec->devnull;
    my %opt = (
        'x' => 1,
        'n' => 0,
        'o' => $par,
        'a' => [@files],
        'p' => 1,
        'B' => $options->{core},
        'm' => $options->{multiarch}
    );
    App::Packer::PAR->new(
        frontend  => 'Module::ScanDeps',
        backend   => 'PAR::Packer',
        frontopts => \%opt,
        backopts  => \%opt,
        args      => ['par_test.pl'],
    )->go;
    open STDERR, '>&', $olderr;

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
