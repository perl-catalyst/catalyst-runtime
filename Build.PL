use strict;
use Module::Build;

my $build = Module::Build->new(
    create_makefile_pl => 'passthrough',
    license            => 'perl',
    module_name        => 'Catalyst',
    requires           => {
        'perl'                              => '5.8.1',
        'UNIVERSAL::require'                => "0.10",
        'Class::Accessor::Fast'             => 0,
        'Class::Data::Inheritable'          => 0,
        'Class::Inspector'                  => 0,
        'CGI::Cookie'                       => 0,
        'File::Modified'                    => 0,
        'HTML::Entities'                    => 0,
        'HTTP::Body'                        => 0.4,
        'HTTP::Headers'                     => 1.59,
        'HTTP::Request'                     => 0,
        'HTTP::Response'                    => 0,
        'LWP::UserAgent'                    => 0,
        'MIME::Types'                       => 0,
        'Module::Pluggable::Fast'           => 0.16,
        'NEXT'                              => 0,
        'Path::Class'                       => 0.09,
        'Scalar::Util'                      => 0,
        'Template'                          => 0,
        'Text::SimpleTable'                 => 0,
        'Test::MockObject'                  => 0,
        'Time::HiRes'                       => 0,
        'Tree::Simple'                      => 0,
        'Tree::Simple::Visitor::FindByPath' => 0,
        'URI'                               => 1.35,
    },
    recommends =>
      { 'Catalyst::Engine::Apache' => 0, FCGI => 0, 'FCGI::ProcManager' => 0 },
    create_makefile_pl => 'passthrough',
    create_readme      => 1,
    script_files       => [ glob('script/*') ],
    test_files         => [
        glob('t/*.t'),     glob('t/*/*.t'),
        glob('t/*/*/*.t'), glob('t/*/*/*/*.t'),
        glob('t/*/*/*/*/*.t')
    ]
);
$build->create_build_script;

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
if ($@) {
    print qq/ Install "FCGI" for FastCGI support.\n/;
}
else {
    eval "use FCGI::ProcManager";
    print
qq/ Install "FCGI::ProcManager" for multiprocess FastCGI external support.\n/
      if ($@);
}

print <<"EOF";

 Important:
     The Apache engines have been moved to a separate package in Catalyst 5.5.
     Please install Catalyst::Engine::Apache if you need Apache support.
EOF
