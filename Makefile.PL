use inc::Module::Install 0.62;

perl_version '5.8.1';

name 'Catalyst';
all_from 'lib/Catalyst.pm';

requires 'perl'               => '5.8.1';
requires 'Carp';
requires 'Class::Accessor::Fast';
requires 'Class::Data::Inheritable';
requires 'Class::Inspector' => '1.06';
requires 'CGI::Simple::Cookie';
requires 'Data::Dump';
requires 'File::Modified';
requires 'HTML::Entities';
requires 'HTTP::Body'    => '0.5';
requires 'HTTP::Headers' => '1.64';
requires 'HTTP::Request';
requires 'HTTP::Response';
requires 'HTTP::Request::AsCGI' => '0.5';
requires 'LWP::UserAgent';
requires 'Module::Pluggable' => '3.0';
requires 'NEXT';
requires 'Path::Class' => '0.09';
requires 'Scalar::Util';
requires 'Text::SimpleTable' => '0.03';
requires 'Time::HiRes';
requires 'Tree::Simple' => '1.15';
requires 'Tree::Simple::Visitor::FindByPath';
requires 'URI' => '1.35';
requires 'Text::Balanced'; # core in 5.8.x but mentioned for completeness

feature 'Apache/mod_perl Support',
  -default                   => 0,
  'Catalyst::Engine::Apache' => '1.05';

feature 'FastCGI Support', -default => 0, 'FCGI' => 0, 'FCGI::ProcManager' => 0;

install_script glob('script/*.pl');
WriteAll;

print( '*' x 80, "\n" );
my $banner =
  (qw/andyg chansen draven fordmason mst naughton sri jester
      nothingmuch LTjake/)[ int( rand(10) ) ]
  . " is the greatest and gabb is "
  . ( (localtime)[2] > 12 ? "drunk" : "hung over" )
  . " again!";
print " $banner \n";
print( '*' x 80, "\n" );

eval "use FCGI";
print qq/ Install "FCGI" for FastCGI support.\n/ if $@;
eval "use FCGI::ProcManager";
print
  qq/ Install "FCGI::ProcManager" for multiprocess FastCGI external support.\n/
  if ($@);
eval "use PAR ()";
print qq/ Install "PAR" for PAR packaging support.\n/ if $@;

print <<"EOF";

 Important:
    Install Task::Catalyst to get everything you need to start writing
    serious applications with Catalyst.

    Note that Catalyst::Helper has been split into a separate distribution,
    and is required for using catalyst.pl to make new distributions. It is
    included with Task::Catalyst

        perl -MCPANPLUS -e 'install Task::Catalyst'
        perl -MCPAN -e 'install Task::Catalyst'

 Have fun!
EOF
