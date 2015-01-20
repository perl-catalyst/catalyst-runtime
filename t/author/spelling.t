use strict;
use warnings;
use Test::More;
use Test::Spelling;

add_stopwords(qw(
    Accel API CGI MVC PSGI Plack README SSI Starman XXXX URI htaccess middleware
    mixins namespace psgi startup Deprecations catamoose cataplack linearize
    subclasses subdirectories refactoring adaptors validator remediations
    undef env regex unary rethrow rethrows stringifies CPAN STDERR SIGCHLD baz
    roadmap wishlist refactor refactored Runtime pluggable pluggability hoc apis
    fastcgi nginx Lighttpd IIS middlewares backend IRC IOLayer
    ctx _application MyApp restarter httponly Utils stash's unescapes
    actionchain dispatchtype dispatchtypes redispatch redispatching
    CaptureArgs ChainedParent PathPart PathPrefix
    BUILDARGS metaclass namespaces pre ARGV ReverseProxy TT UI
    filename tempname request's subdirectory ini uninstalled uppercased
    wiki bitmask uri url urls dir hostname proxied http https IP SSL
    inline INLINE plugins cpanfile resized
    FastCGI Stringifies Rethrows DispatchType Wishlist Refactor ROADMAP HTTPS Unescapes Restarter Nginx Refactored
    ActionClass LocalRegex LocalRegexp MyAction metadata cometd io psgix websocket websockets proxying
    UTF unicode async codebase dev encodable filenames params MyMiddleware Sendfile
    JSON xml POSTs POSTed RESTful performant subref actionrole
    chunked chunking codewise distingush equivilent plack Javascript gzipping
    ConfigLoader getline whitepaper matchable
    Andreas
    André
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
    Styn
    Szilakszi
    Tatsuhiko
    Ulf
    Upasana
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
    davewood
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
    jnap
    jon
    konobi
    marcus
    mgrimes
    miyagawa
    mst
    Napiorkowski
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
    vanstyn
    willert
    wreis
));
set_spell_cmd('aspell list -l en');
all_pod_files_spelling_ok();

done_testing();
