use inc::Module::Install;

# ExtUtils::AutoInstall Bootstrap Code, version 7.
BEGIN {
    my $p = 'ExtUtils::AutoInstall';
    my $v = 0.45;
    $p->VERSION || 0 >= $v
      or +eval "use $p $v;1"
      or +do {
        my $e = $ENV{PERL_EXTUTILS_AUTOINSTALL};
        (
            !defined($e) || $e !~ m/--(?:default|skip|testonly)/ and -t STDIN
              or eval
              "use ExtUtils::MakeMaker;WriteMakefile(PREREQ_PM=>{'$p',$v}
);1" and exit
          )
          and print "==> $p $v required. Install it from CP" . "AN? [Y/n] "
          and <STDIN> !~ /^n/i
          and print "*** Installing $p\n"
          and do {
            if ( eval '$>' and lc(`sudo -V`) =~ /version/ ) {
                system( 'sudo', $^X, "-MCPANPLUS", "-e",
                    "CPANPLUS::install $p" );
                eval "use $p $v;1"
                  || system( 'sudo', $^X, "-MCPAN", "-e", "CPAN::install $p" );
            }
            eval {
                require CPANPLUS;
                CPANPLUS::install $p;
            };
            eval "use $p $v;1" or eval {
                require CPAN;
                CPAN::install $p;
            };
            eval "use $p $v;1" || die "*** Please
manually install $p $v from cpan.org first...\n";
          }
      }
}

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
requires('File::Copy::Recursive');
requires('Module::Install::Admin');

features(
    'Apache/mod_perl Support' => [
        -default                   => 0,
        'Catalyst::Engine::Apache' => '1.00'
    ],
    'FastCGI Support' => [
        -default            => 0,
        'FCGI'              => 0,
        'FCGI::ProcManager' => 0
    ],
    'PAR Support' => [
        -default => 0,
        'PAR'    => 0
    ],
    'CPANPLUS (for easier installations)' => [
        -default   => 0,
        'CPANPLUS' => 0
    ],
);

install_script( glob('script/*.pl') );
auto_install();
&WriteAll;

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
