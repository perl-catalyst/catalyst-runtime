use strict;
use warnings;
use inc::Module::Install 0.87;
BEGIN { # Make it easy for newbies
    if ($Module::Install::AUTHOR) {
        require Module::Install::AuthorRequires;
        require Module::Install::CheckConflicts;
        require Module::Install::AuthorTests;
    }
}
perl_version '5.008006';

name 'Catalyst-Runtime';
all_from 'lib/Catalyst/Runtime.pm';

requires 'List::MoreUtils';
requires 'namespace::autoclean';
requires 'namespace::clean';
requires 'B::Hooks::EndOfScope' => '0.08';
requires 'MooseX::Emulate::Class::Accessor::Fast' => '0.00801';
requires 'Class::MOP' => '0.83';
requires 'Moose' => '0.78';
requires 'MooseX::MethodAttributes::Inheritable' => '0.15';
requires 'Carp';
requires 'Class::C3::Adopt::NEXT' => '0.07';
requires 'CGI::Simple::Cookie';
requires 'Data::Dump';
requires 'HTML::Entities';
requires 'HTTP::Body'    => '1.04'; # makes uploadtmp work
requires 'HTTP::Headers' => '1.64';
requires 'HTTP::Request';
requires 'HTTP::Response';
requires 'HTTP::Request::AsCGI' => '0.8';
requires 'LWP::UserAgent';
requires 'Module::Pluggable' => '3.9';
requires 'Path::Class' => '0.09';
requires 'Scalar::Util';
requires 'Sub::Exporter';
requires 'Text::SimpleTable' => '0.03';
requires 'Time::HiRes';
requires 'Tree::Simple' => '1.15';
requires 'Tree::Simple::Visitor::FindByPath';
requires 'URI' => '1.35';
requires 'Task::Weaken';
requires 'Text::Balanced'; # core in 5.8.x but mentioned for completeness
requires 'MRO::Compat';
requires 'String::RewritePrefix' => '0.004'; # Catalyst::Utils::resolve_namespace

recommends 'B::Hooks::OP::Check::StashChange';

test_requires 'Class::Data::Inheritable';
test_requires 'Test::Exception';

# aggregate tests if AGGREGATE_TESTS is set and a recent Test::Aggregate and a Test::Simple it works with is available
if ($ENV{AGGREGATE_TESTS} && can_use('Test::Simple', '0.88') && can_use('Test::Aggregate', '0.35_05')) {
    author_requires('Test::Aggregate', '0.35_05');
    author_requires('Test::Simple', '0.88');
}
else {
    tests join q{ },
        grep { $_ ne 't/aggregate.t' }
        map  { glob } qw[t/*.t t/aggregate/*.t];
}

author_tests 't/author';
author_requires(map {; $_ => 0 } qw(
  Test::NoTabs
  Test::Pod
  Test::Pod::Coverage
  Pod::Coverage
));

if ($Module::Install::AUTHOR) {
    darwin_check_no_resource_forks();
}

resources(
    'MailingList' => 'http://lists.scsys.co.uk/cgi-bin/mailman/listinfo/catalyst',
    'IRC'         => 'irc://irc.perl.org/#catalyst',
    'license',    => 'http://dev.perl.org/licenses/',
    'homepage',   => 'http://dev.catalyst.perl.org/',
    'repository', => 'http://dev.catalyst.perl.org/repos/Catalyst/Catalyst-Runtime/',
);

install_script glob('script/*.pl');
auto_install;
WriteAll;

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
    'Catalyst::Component::ACCEPT_CONTEXT' => '0.06',
    'Catalyst::Plugin::ENV' => '9999', # This plugin is just stupid, full stop
                                       # should have been a core fix.
    'Catalyst::Plugin::Unicode::Encoding' => '0.2',
    'Catalyst::Authentication::Credential::HTTP' => '1.009',
    'Catalyst::Plugin::Session::Store::File' => '0.16',
    'Catalyst::Plugin::Session' => '0.21',
    'Catalyst::Plugin::Session::State::Cookie' => '0.10',
    'Catalyst::Plugin::Session::Store::FastMmap' => '0.09',
    'Catalyst::Controller::AllowDisable' => '0.03',
    'Reaction' => '0.001999',
    'Catalyst::Plugin::Upload::Image::Magick' => '0.03',
    'Catalyst::Plugin::ConfigLoader'   => '0.22', # Older versions work but
                                                  # throw Data::Visitor warns
    'Catalyst::Devel'                  => '1.19',
    'Catalyst::Plugin::SmartURI'       => '0.032',
    'CatalystX::CRUD'                  => '0.37',
    'Catalyst::Action::RenderView'     => '0.07',
    'Catalyst::Plugin::DebugCookie'    => '0.999002',
    'Catalyst::Plugin::Authentication' => '0.100091',
    'CatalystX::Imports'               => '0.03',
    'Catalyst::Plugin::HashedCookies'  => '1.03',
    'Catalyst::Action::REST'           => '0.67',
    'CatalystX::CRUD'                  => '0.42',
    'CatalystX::CRUD::Model::RDBO'     => '0.20',
    'Catalyst::View::Mason'            => '0.17',
);
check_conflicts(%conflicts);

# End of script, helper functions below.

sub darwin_check_no_resource_forks {
    if ($^O eq 'darwin') {
        my $osx_ver = `/usr/bin/sw_vers -productVersion`;
        chomp $osx_ver;

        # TAR on 10.4 wants COPY_EXTENDED_ATTRIBUTES_DISABLE
        # On 10.5 (Leopard) it wants COPYFILE_DISABLE
        die("Oh, you got Snow Lepoard, snazzy. Please read the man page for tar to find out if Apple renamed COPYFILE_DISABLE again and fix this Makefile.PL please?\n") if $osx_ver =~ /^10.6/;
        my $attr = $osx_ver =~ /^10.5/ ? 'COPYFILE_DISABLE' : 'COPY_EXTENDED_ATTRIBUTES_DISABLE';

        makemaker_args(dist => { PREOP => qq{\@if [ "\$\$$attr" != "true" ]; then}.
                                          qq{ echo "You must set the ENV variable $attr to true,"; }.
                                          ' echo "to avoid getting resource forks in your dist."; exit 255; fi' });
    }
}
