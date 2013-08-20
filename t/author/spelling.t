use strict;
use warnings;
use Test::More;
use Test::Spelling;

add_stopwords(qw(
    API CGI MVC PSGI Plack README SSI Starman XXXX URI htaccess middleware
    mixins namespace psgi startup Deprecations catamoose cataplack linearize
    subclasses subdirectories refactoring adaptors
    undef env regex unary rethrow rethrows stringifies CPAN STDERR SIGCHLD baz
    roadmap wishlist refactor refactored Runtime pluggable pluggability hoc apis
    fastcgi nginx Lighttpd IIS middlewares backend IRC
    ctx _application MyApp restarter httponly Utils stash's unescapes
    dispatchtype dispatchtypes redispatch redispatching
    CaptureArgs ChainedParent PathPart PathPrefix
    BUILDARGS metaclass namespaces pre ARGV ReverseProxy
    filename tempname request's subdirectory ini uninstalled uppercased
    wiki bitmask uri url urls dir hostname proxied http https IP SSL
    inline INLINE plugins cpanfile
    FastCGI Stringifies Rethrows DispatchType Wishlist Refactor ROADMAP HTTPS Unescapes Restarter Nginx Refactored
    ActionClass LocalRegex LocalRegexp MyAction metadata cometd io psgix websockets
    UTF async codebase dev filenames params MyMiddleware
    JSON POSTed RESTful configuation performant subref
    Andreas
    Ashton
    Axel
    Balint
    Belka
    Brocard
    Caelum
    Cassidy
    Dagfinn
    Danijel
    Dhanani
    Dhaval
    Diment
    Doran
    Edvinsson
    Florian
    Geoff
    Grundman
    Hartmaier
    Hawes
    Ilmari
    Johan
    Kamholz
    Kiefer
    Kieren
    Kitover
    Kogman
    Kostyuk
    Kubb
    Lammel
    Lindstrom
    Mannsåker
    Marienborg
    Marrandi
    McWhirter
    Milicevic
    Miyagawa
    Montes
    Naughton
    Oleg
    Ragwitz
    Ramberg
    Rasnita
    Reis
    Riedel
    Rockway
    Roditi
    Rodland
    Ruthven
    Sascha
    Schutz
    Sedlacek
    Sheidlower
    SpiceMan
    Szilakszi
    Tatsuhiko
    Ulf
    Vilain
    Viljo
    Wardley
    Westermann
    Willert
    Yuval
    abraxxa
    abw
    andyg
    audreyt
    bricas
    chansen
    dhoss
    dkubb
    dwc
    esskar
    fREW
    fireartist
    frew
    gabb
    groditi
    hobbs
    ilmari
    jcamacho
    jhannah
    jon
    konobi
    marcus
    mgrimes
    miyagawa
    mst
    naughton
    ningu
    nothingmuch
    numa
    obra
    phaylon
    rafl
    rainboxx
    sri
    szbalint
    willert
    wreis
));
set_spell_cmd('aspell list -l en');
all_pod_files_spelling_ok();

done_testing();
