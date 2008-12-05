use inc::Module::Install 0.64;

perl_version '5.008001';

name 'Catalyst-Runtime';
all_from 'lib/Catalyst/Runtime.pm';

requires 'namespace::clean';
requires 'MooseX::Emulate::Class::Accessor::Fast' => '0.00400';
requires 'Moose' => '0.59';
requires 'Carp';
requires 'Class::C3::Adopt::NEXT';
requires 'Class::MOP';
requires 'CGI::Simple::Cookie';
requires 'Data::Dump';
requires 'File::Modified';
requires 'HTML::Entities';
requires 'HTTP::Body'    => '1.04'; # makes uploadtmp work
requires 'HTTP::Headers' => '1.64';
requires 'HTTP::Request';
requires 'HTTP::Response';
requires 'HTTP::Request::AsCGI' => '0.5';
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

test_requires 'Class::Data::Inheritable';

if (   ( exists $ENV{AGGREGATE_TESTS} && !$ENV{AGGREGATE_TESTS})
    || (!exists $ENV{AGGREGATE_TESTS} && !can_use('Test::Aggregate', '0.34_01'))) {
    tests join q{ },
        grep { $_ ne 't/aggregate.t' }
        map  { glob } qw[t/*.t t/aggregate/*.t];
}

if (-e 'inc/.author') {
  build_requires 'Test::NoTabs';
  build_requires 'Test::Pod' => 1.14;
  build_requires 'Test::Pod::Coverage' => 1.04;

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
