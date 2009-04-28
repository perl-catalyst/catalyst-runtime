use inc::Module::Install 0.64;

perl_version '5.008001';

name 'Catalyst-Runtime';
all_from 'lib/Catalyst/Runtime.pm';

requires 'namespace::clean';
requires 'Scope::Upper' => '0.06';
requires 'MooseX::Emulate::Class::Accessor::Fast' => '0.00801';
requires 'Class::MOP' => '0.83';
requires 'Moose' => '0.76';
requires 'MooseX::MethodAttributes::Inheritable' => '0.09';
requires 'Carp';
requires 'Class::C3::Adopt::NEXT' => '0.07';
requires 'CGI::Simple::Cookie';
requires 'Data::Dump';
requires 'File::Modified';
requires 'HTML::Entities';
requires 'HTTP::Body'    => '1.04'; # makes uploadtmp work
requires 'HTTP::Headers' => '1.64';
requires 'HTTP::Request';
requires 'HTTP::Response';
requires 'HTTP::Request::AsCGI' => '0.8';
requires 'LWP::UserAgent';
requires 'Module::Pluggable' => '3.01';
requires 'Path::Class' => '0.09';
requires 'Scalar::Util';
requires 'Sub::Exporter';
requires 'Text::SimpleTable' => '0.03';
requires 'Time::HiRes';
requires 'Tree::Simple' => '1.15';
requires 'Tree::Simple::Visitor::FindByPath';
requires 'URI' => '1.35';
requires 'Text::Balanced'; # core in 5.8.x but mentioned for completeness
requires 'MRO::Compat';

recommends 'B::Hooks::OP::Check::StashChange';

test_requires 'Class::Data::Inheritable';
test_requires 'Test::MockObject';

# aggregate tests if AGGREGATE_TESTS is set and a recent Test::Aggregate is available
if ($ENV{AGGREGATE_TESTS} && can_use('Test::Aggregate', '0.34_01')) {
    test_requires('Test::Aggregate', '0.34_01');
}
else {
    tests join q{ },
        grep { $_ ne 't/aggregate.t' }
        map  { glob } qw[t/*.t t/aggregate/*.t];
}

my @force_build_requires_if_author = qw(
  Test::NoTabs
  Test::Pod
  Test::Pod::Coverage
  Pod::Coverage
);

if ($Module::Install::AUTHOR) {
    foreach my $module (@force_build_requires_if_author) {
        build_requires $module;
    }
    darwin_check_no_resource_forks();
}

install_script glob('script/*.pl');
auto_install;
WriteAll;

if ($Module::Install::AUTHOR) {

  # Strip out the author only build_requires from META.yml
  # Need to do this _after_ WriteAll else it looses track of them
  strip_author_only_build_requires(@force_build_requires_if_author);

  Meta->{values}{resources} = [
    [ 'MailingList' => 'http://lists.scsys.co.uk/cgi-bin/mailman/listinfo/catalyst' ],
    [ 'IRC'         => 'irc://irc.perl.org/#catalyst' ],
    [ 'license',    => 'http://dev.perl.org/licenses/' ],
    [ 'homepage',   => 'http://dev.catalyst.perl.org/'],
    [ 'repository', => 'http://dev.catalyst.perl.org/repos/Catalyst/Catalyst-Runtime/' ],
  ];

  Meta->write;
}

print <<"EOF";

 Important:

    This library is for running Catalyst applications.

    For development and use of catalyst.pl and myapp_create.pl, make sure
    you also install the development tools package Catalyst::Devel.

        perl -MCPANPLUS -e 'install Catalyst::Devel' # or
        perl -MCPAN -e 'install Catalyst::Devel'

    To get some commonly used plugins, as well as the TT view and DBIC 
    model, install Task::Catalyst in the same way.

 Have fun!
EOF

# NOTE - This is the version number of the _incompatible_ code,
#        not the version number of the fixed version.
my %conflicts = (
    'Catalyst::Plugin::ConfigLoader'   => '0.22', # Older versions work but
                                                  # throw Data::Visitor warns
    'Catalyst::Devel'                  => '0.09',
    'Catalyst::Plugin::SmartURI'       => '0.029',
    'CatalystX::CRUD'                  => '0.37',
    'Catalyst::Action::RenderView'     => '0.07',
    'Catalyst::Plugin::DebugCookie'    => '0.999002',
    'Catalyst::Plugin::Authentication' => '0.100091',
    'CatalystX::Imports'               => '0.03',
    'Catalyst::Plugin::HashedCookies'  => '1.03',
    'Catalyst::Action::REST'           => '0.67',
);
check_conflicts(%conflicts);

# End of script, helper functions below.

sub darwin_check_no_resource_forks {
    if ($^O eq 'darwin') {
        my $osx_ver = `/usr/bin/sw_vers -productVersion`;
        chomp $osx_ver;

        # TAR on 10.4 wants COPY_EXTENDED_ATTRIBUTES_DISABLE
        # On 10.5 (Leopard) it wants COPYFILE_DISABLE
        my $attr = $osx_ver eq '10.5' ? 'COPYFILE_DISABLE' : 'COPY_EXTENDED_ATTRIBUTES_DISABLE';

        makemaker_args(dist => { PREOP => qq{\@if [ "\$\$$attr" != "true" ]; then}.
                                          qq{ echo "You must set the ENV variable $attr to true,"; }.
                                          ' echo "to avoid getting resource forks in your dist."; exit 255; fi' });
        }
}

sub strip_author_only_build_requires {
    my @build_requires_to_strip = @_;
    Meta->{values}{build_requires} = [ grep {
      my $ok = 1;
      foreach my $module (@build_requires_to_strip) {
        if ($_->[0] =~ /$module/) {
          $ok = 0;
          last;
        }
      }
      $ok;
    } @{Meta->{values}{build_requires}} ];
}

sub check_conflicts {
    my %conflicts = @_;

    my %conflicts_found;
    for my $mod ( sort keys %conflicts ) {
        eval "require($mod)";
        next if $@;

        my $installed = $mod->VERSION();
        $conflicts_found{$mod} = $installed if ( $installed le $conflicts{$mod} );
    }

    return unless scalar keys %conflicts_found;

    print <<"EOF";

 WARNING:

    This version of Catalyst conflicts with the versions of
    some components you have installed.

    You will need to upgrade these modules after installing
    this version of Catalyst.

    List of the conflicting components and their installed versions:

EOF

    foreach my $mod (keys %conflicts_found) {
        print sprintf("    %s => %s\n", $mod, $conflicts_found{$mod});
    }
    print "\n";

    # More or less copied from Module::Build, via Moose
    return if $ENV{PERL_MM_USE_DEFAULT};
    return unless -t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT));

    sleep 4;
}
