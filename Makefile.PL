use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Catalyst',
    VERSION_FROM => 'lib/Catalyst.pm',
    EXE_FILES    => ['bin/catalyst'],
    PREREQ_PM    => {
        UNIVERSAL::require       => 0,
        CGI::Simple              => 0,
        Class::Accessor::Fast    => 0,
        Class::Data::Inheritable => 0,
        HTML::Entities           => 0,
        HTTP::Headers            => 0,
        Module::Pluggable::Fast  => 0
    }
);

my $gabb =
  int( rand(2) ) == 1
  ? "Gabbana is the greatest!"
  : "Gabbana is drunk again!";
print "$gabb\n";
