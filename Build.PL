use strict;
use Module::Build;

my $build = Module::Build->new(
    create_makefile_pl => 'passthrough',
    license            => 'perl',
    module_name        => 'Catalyst',
    requires           => {
        'perl'                              => '5.8.1',
        'UNIVERSAL::require'                => 0,
        'CGI'                               => '3.06',
        'Class::Accessor::Fast'             => 0,
        'Class::Data::Inheritable'          => 0,
        'File::Temp'                        => 0.14,
        'HTTP::Daemon'                      => 0,
        'HTML::Entities'                    => 0,
        'HTTP::Headers'                     => 1.59,
        'HTTP::Request'                     => 0,
        'HTTP::Response'                    => 0,
        'LWP::UserAgent'                    => 0,
        'Module::Pluggable::Fast'           => 0.16,
        'Path::Class'                       => 0.09,
        'Template'                          => 0,
        'Text::ASCIITable'                  => 0,
        'Tree::Simple'                      => 0,
        'Tree::Simple::Visitor::FindByPath' => 0,
        'URI'                               => 0,
    },
    create_makefile_pl => 'passthrough',
    create_readme => 1,
    script_files => [ glob('script/*') ],
    test_files   => [
        glob('t/*.t'), glob('t/*/*.t'), glob('t/*/*/*.t'), glob('t/*/*/*/*.t')
    ]
);
$build->create_build_script;

print( '*' x 80, "\n" );
print(
    (qw/chansen draven fordmason naughton sri the_jester/)[ int( rand(6) ) ],
    " is the greatest and gabb is ",
    ( (localtime)[2] > 12 ? "drunk" : "hung over" ),
    " again!\n"
);
print( '*' x 80, "\n" );

eval "use FCGI";
print qq/Install "FCGI" for FastCGI support.\n/ if $@;
