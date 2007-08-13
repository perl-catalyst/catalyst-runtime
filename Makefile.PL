use inc::Module::Install 0.64;

perl_version '5.8.1';

name 'Catalyst-Runtime';
all_from 'lib/Catalyst/Runtime.pm';

requires 'perl'               => '5.8.1';
requires 'Carp';
requires 'Class::Accessor::Fast';
requires 'Class::Data::Inheritable';
requires 'Class::Inspector' => '1.06';
requires 'CGI::Simple::Cookie';
requires 'Data::Dump';
requires 'File::Modified';
requires 'HTML::Entities';
requires 'HTTP::Body'    => '0.9';
requires 'HTTP::Headers' => '1.64';
requires 'HTTP::Request';
requires 'HTTP::Response';
requires 'HTTP::Request::AsCGI' => '0.5';
requires 'LWP::UserAgent';
requires 'Module::Pluggable' => '3.01';
requires 'NEXT';
requires 'Path::Class' => '0.09';
requires 'Scalar::Util';
requires 'Text::SimpleTable' => '0.03';
requires 'Time::HiRes';
requires 'Tree::Simple' => '1.15';
requires 'Tree::Simple::Visitor::FindByPath';
requires 'URI' => '1.35';
requires 'Text::Balanced'; # core in 5.8.x but mentioned for completeness

if (-e 'inc/.author') {
  build_requires 'Test::Perl::Critic';
}

install_script glob('script/*.pl');
auto_install;
WriteAll;

print( '*' x 74, "\n" );
my $banner =
  (qw/andyg chansen draven fordmason mst naughton sri jester
      jrockway ningu nothingmuch LTjake/)[ int( rand(12) ) ]
  . " is the greatest and gabb is "
  . ( (localtime)[2] > 12 ? "drunk" : "hung over" )
  . " again!";
print " $banner \n";
print( '*' x 74, "\n" );

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
