package Module::Install::Catalyst;

use strict;
use base 'Module::Install::Base';
use File::Find;
use FindBin;
use File::Copy::Recursive 'rcopy';
use File::Spec ();

our @IGNORE =
  qw/Build Build.PL Changes MANIFEST META.yml Makefile.PL Makefile README
  _build blib lib script t inc/;
our @CLASSES   = ();
our $ENGINE    = 'CGI';
our $CORE      = 0;
our $MULTIARCH = 0;
our $SCRIPT;
our $USAGE;

=head1 NAME

Module::Install::Catalyst - Module::Install extension for Catalyst

=head1 SYNOPSIS

See L<Catalyst>

=head1 DESCRIPTION

L<Module::Install> extension for Catalyst.

=head1 METHODS

=head2 catalyst_files

=cut

sub catalyst_files {
    my $self = shift;

    chdir $FindBin::Bin;

    my @files;
    opendir CATDIR, '.';
  CATFILES: for my $name ( readdir CATDIR ) {
        for my $ignore (@IGNORE) {
            next CATFILES if $name =~ /^$ignore$/;
            next CATFILES if $name !~ /\w/;
        }
        push @files, $name;
    }
    closedir CATDIR;
    my @path = split '::', $self->name;
    for my $orig (@files) {
        my $path = File::Spec->catdir( 'blib', 'lib', @path, $orig );
        rcopy( $orig, $path );
    }
}

=head2 catalyst_ignore_all(\@ignore)

=cut

sub catalyst_ignore_all {
    my ( $self, $ignore ) = @_;
    @IGNORE = @$ignore;
}

=head2 catalyst_ignore(\@ignore)

=cut

sub catalyst_ignore {
    my ( $self, @ignore ) = @_;
    push @IGNORE, @ignore;
}

=head2 catalyst_par($name)

=cut

# Workaround for a namespace conflict
sub catalyst_par { Catalyst::Module::Install::_catalyst_par(@_) }

=head2 catalyst_par_core($core)

=cut

sub catalyst_par_core {
    my ( $self, $core ) = @_;
    $core ? ( $CORE = $core ) : $core++;
}

=head2 catalyst_par_classes(@clases)

=cut

sub catalyst_par_classes {
    my ( $self, @classes ) = @_;
    push @CLASSES, @classes;
}

=head2 catalyst_par_engine($engine)

=cut

sub catalyst_par_engine {
    my ( $self, $engine ) = @_;
    $ENGINE = $engine;
}

=head2 catalyst_par_multiarch($multiarch)

=cut

sub catalyst_par_multiarch {
    my ( $self, $multiarch ) = @_;
    $multiarch ? ( $MULTIARCH = $multiarch ) : $multiarch++;
}

=head2 catalyst_par_script($script)

=cut

sub catalyst_par_script {
    my ( $self, $script ) = @_;
    $SCRIPT = $script;
}

=head2 catalyst_par_usage($usage)

=cut

sub catalyst_par_usage {
    my ( $self, $usage ) = @_;
    $USAGE = $usage;
}

package Catalyst::Module::Install;

use strict;
use FindBin;
use File::Copy::Recursive 'rmove';
use File::Spec ();

sub _catalyst_par {
    my ( $self, $par ) = @_;

    my $name = $self->name;
    $name =~ s/::/_/g;
    $name = lc $name;
    $par ||= "$name.par";
    my $engine = $Module::Install::Catalyst::ENGINE || 'CGI';

    # Check for PAR
    eval "use PAR ()";
    die "Please install PAR\n" if $@;
    eval "use PAR::Packer ()";
    die "Please install PAR::Packer\n" if $@;
    eval "use App::Packer::PAR ()";
    die "Please install App::Packer::PAR\n" if $@;
    eval "use Module::ScanDeps ()";
    die "Please install Module::ScanDeps\n" if $@;

    my $root = $FindBin::Bin;
    my $path = File::Spec->catfile( 'blib', 'lib', split( '::', $self->name ) );
    $path .= '.pm';
    unless ( -f $path ) {
        print qq/Not writing PAR, "$path" doesn't exist\n/;
        return 0;
    }
    print qq/Writing PAR "$par"\n/;
    chdir File::Spec->catdir( $root, 'blib' );

    my $par_pl = 'par.pl';
    unlink $par_pl;

    my $version = $Catalyst::VERSION;
    my $class   = $self->name;

    my $classes = '';
    $classes .= "    require $_;\n" for @Catalyst::Module::Install::CLASSES;

    unlink $par_pl;

    my $usage = $Module::Install::Catalyst::USAGE || <<"EOF";
Usage:
    [parl] $name\[.par] [script] [arguments]

  Examples:
    parl $name.par $name\_server.pl -r
    myapp $name\_cgi.pl
EOF

    my $script   = $Module::Install::Catalyst::SCRIPT;
    my $tmp_file = IO::File->new("> $par_pl ");
    print $tmp_file <<"EOF";
if ( \$ENV{PAR_PROGNAME} ) {
    my \$zip = \$PAR::LibCache{\$ENV{PAR_PROGNAME}}
        || Archive::Zip->new(__FILE__);
    my \$script = '$script';
    \$ARGV[0] ||= \$script if \$script;
    if ( ( \@ARGV == 0 ) || ( \$ARGV[0] eq '-h' ) || ( \$ARGV[0] eq '-help' )) {
        my \@members = \$zip->membersMatching('.*script/.*\.pl');
        my \$list = "  Available scripts:\\n";
        for my \$member ( \@members ) {
            my \$name = \$member->fileName;
            \$name =~ /(\\w+\\.pl)\$/;
            \$name = \$1;
            next if \$name =~ /^main\.pl\$/;
            next if \$name =~ /^par\.pl\$/;
            \$list .= "    \$name\\n";
        }
        die <<"END";
$usage
\$list
END
    }
    my \$file = shift \@ARGV;
    \$file =~ s/^.*[\\/\\\\]//;
    \$file =~ s/\\.[^.]*\$//i;
    my \$member = eval { \$zip->memberNamed("./script/\$file.pl") };
    die qq/Can't open perl script "\$file"\n/ unless \$member;
    PAR::_run_member( \$member, 1 );
}
else {
    require lib;
    import lib 'lib';
    \$ENV{CATALYST_ENGINE} = '$engine';
    require $class;
    import $class;
    require Catalyst::Helper;
    require Catalyst::Test;
    require Catalyst::Engine::HTTP;
    require Catalyst::Engine::CGI;
    require Catalyst::Controller;
    require Catalyst::Model;
    require Catalyst::View;
    require Getopt::Long;
    require Pod::Usage;
    require Pod::Text;
    $classes
}
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
        'a' => [ grep( !/par.pl/, glob '.' ) ],
        'p' => 1,
        'B' => $Module::Install::Catalyst::CORE,
        'm' => $Module::Install::Catalyst::MULTIARCH
    );
    App::Packer::PAR->new(
        frontend  => 'Module::ScanDeps',
        backend   => 'PAR::Packer',
        frontopts => \%opt,
        backopts  => \%opt,
        args      => ['par.pl'],
    )->go;

    open STDERR, '>&', $olderr;

    unlink $par_pl;
    chdir $root;
    rmove( File::Spec->catfile( 'blib', $par ), $par );
    return 1;
}

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
