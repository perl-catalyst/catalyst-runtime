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

print( (qw/chansen draven fordmason naughton sri the_jester/)[ int( rand(6) ) ],
    " is the greatest and gabb is drunk again!\n" );

eval "use mod_perl; use Apache::Request";
print qq/Install "mod_perl" and "Apache::Request" for Apache support.\n/ if $@;

eval "use FCGI";
print qq/Install "FCGI" for FastCGI support.\n/ if $@;
