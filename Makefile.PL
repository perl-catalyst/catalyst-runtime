use inc::Module::Install;

name 'Catalyst';
all_from 'lib/Catalyst.pm';

requires 'perl'               => '5.8.1';
requires 'UNIVERSAL::require' => "0.10";
requires 'Class::Accessor::Fast';
requires 'Class::Data::Inheritable';
requires 'Class::Inspector';
requires 'CGI::Cookie';
requires 'File::Modified';
requires 'HTML::Entities';
requires 'HTTP::Body'    => 0.5;
requires 'HTTP::Headers' => 1.59;
requires 'HTTP::Request';
requires 'HTTP::Response';
requires 'HTTP::Request::AsCGI' => '0.5';
requires 'LWP::UserAgent';
requires 'MIME::Types';
requires 'Module::Pluggable::Fast' => 0.16;
requires 'NEXT';
requires 'Path::Class' => 0.09;
requires 'Scalar::Util';
requires 'Template';
requires 'Text::SimpleTable' => 0.03;
requires 'Test::MockObject';
requires 'Test::NoWarnings' => 0.082;
requires 'Time::HiRes';
requires 'Tree::Simple' => 1.15;
requires 'Tree::Simple::Visitor::FindByPath';
requires 'URI' => 1.35;
requires 'File::Copy::Recursive';
requires 'Module::Install::Admin' => '0.54';
requires 'Module::Install' => '0.54';
requires 'YAML' => '0.52';

feature 'Apache/mod_perl Support',
  -default                   => 0,
  'Catalyst::Engine::Apache' => '1.05';

feature 'FastCGI Support', -default => 0, 'FCGI' => 0, 'FCGI::ProcManager' => 0;

feature 'PAR Support',
  -default => 0,
  'PAR'    => 0;

feature 'CPANPLUS (for easier installations)',
  -default   => 0,
  'CPANPLUS' => 0;

install_script glob('script/*.pl');
auto_install;
WriteAll;

print( '*' x 80, "\n" );
my $banner =
  (qw/andyg chansen draven fordmason mst naughton sri jester/)[ int( rand(8) ) ]
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

        perl -MCPANPLUS -e 'install Task::Catalyst'
        perl -MCPAN -e 'install Task::Catalyst'

 Have fun!
EOF
