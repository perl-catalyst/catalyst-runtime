use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Catalyst',
    VERSION_FROM => 'lib/Catalyst.pm',
    EXE_FILES    => ['script/catalyst.pl'],
    PREREQ_PM    => {
        UNIVERSAL::require       => 0,
        CGI::Simple              => 0,
        Class::Accessor::Fast    => 0,
        Class::Data::Inheritable => 0,
        HTML::Entities           => 0,
        HTTP::Headers            => 0,
        HTTP::Server::Simple     => '0.04',
        Module::Pluggable::Fast  => 0
    }
);

print(
    (qw/draven naughton sri the_jester/)[ int( rand(4) ) ],
    " is the greatest and gabb is drunk again!\n"
);
