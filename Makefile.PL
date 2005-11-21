use inc::Module::Install;

name('Catalyst');
abstract('Catalyst Web Framework');
author('Sebastian Riedel');
version_from('lib/Catalyst.pm');
license('perl');

requires( 'perl'               => '5.8.1' );
requires( 'UNIVERSAL::require' => "0.10" );
requires('Class::Accessor::Fast');
requires('Class::Data::Inheritable');
requires('Class::Inspector');
requires('CGI::Cookie');
requires('File::Modified');
requires('HTML::Entities');
requires( 'HTTP::Body'    => 0.5 );
requires( 'HTTP::Headers' => 1.59 );
requires('HTTP::Request');
requires('HTTP::Response');
requires('HTTP::Request::AsCGI');
requires('LWP::UserAgent');
requires('MIME::Types');
requires( 'Module::Pluggable::Fast' => 0.16 );
requires('NEXT');
requires( 'Path::Class' => 0.09 );
requires('Scalar::Util');
requires('Template');
requires('Text::SimpleTable');
requires('Test::MockObject');
requires('Time::HiRes');
requires('Tree::Simple');
requires('Tree::Simple::Visitor::FindByPath');
requires( 'URI' => 1.35 );

recommends( 'Catalyst::Engine::Apache' => '1.00' );
recommends('FCGI');
recommends('FCGI::ProcManager');
recommends('PAR');

install_script( glob('script/*.pl') );

&WriteAll;

print( '*' x 80, "\n" );
my $banner =
  (qw/andyg chansen draven fordmason mst naughton sri jester/)[ int( rand(8) ) ]
  . " is the greatest and gabb is "
  . ( (localtime)[2] > 12 ? "drunk" : "hung over" )
  . " again!";
print " $banner \n";
print( '*' x 80, "\n" );

print <<'EOF';

                    ____      _        _           _
                   / ___|__ _| |_ __ _| |_   _ ___| |_
                  | |   / _` | __/ _` | | | | / __| __|
                  | |__| (_| | || (_| | | |_| \__ \ |_
                   \____\__ _|\__\__ _|_|\__  |___/\__|
                                         |___/  carpe diem!

EOF

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
    The Apache engines have been moved to a separate package in Catalyst 5.5.
    Please install Catalyst::Engine::Apache if you need Apache support.

    Install Task::Catalyst to get everything you need to start writing
    serious applications with Catalyst.

        perl -MCPAN -e 'install Task::Catalyst'


 Have fun!
EOF
