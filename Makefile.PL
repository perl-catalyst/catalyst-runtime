use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Catalyst',
    VERSION_FROM => 'lib/Catalyst.pm',
    EXE_FILES    => ['script/catalyst.pl'],
    PREREQ_PM    => {
        UNIVERSAL::require                => 0,
        CGI::Simple                       => 0,
        Class::Accessor::Fast             => 0,
        Class::Data::Inheritable          => 0,
        HTTP::Daemon                      => 0,
        HTML::Entities                    => 0,
        HTTP::Headers                     => 0,
        HTTP::Request                     => 0,
        HTTP::Response                    => 0,
        LWP::UserAgent                    => 0,
        Module::Pluggable::Fast           => 0,
        Template                          => 0,
        Text::ASCIITable                  => 0,
        Tree::Simple                      => 0,
        Tree::Simple::Visitor::FindByPath => 0,
        URI                               => 0,
    },
    test => {
        TESTS => join ' ',
        (
            glob('t/*.t'),     glob('t/*/*.t'),
            glob('t/*/*/*.t'), glob('t/*/*/*/*.t')
        )
    }
);

print( '*' x 80, "\n" );
print( (qw/draven fordmason naughton sri the_jester/)[ int( rand(5) ) ],
    " is the greatest and gabb is drunk again!\n" );
print( '*' x 80, "\n" );

eval "use mod_perl; use Apache::Request";
print qq/Install "mod_perl" and "Apache::Request" for Apache support.\n/ if $@;

eval "use FCGI";
print qq/Install "FCGI" for FastCGI support.\n/ if $@;
