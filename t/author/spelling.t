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
));
set_spell_cmd('aspell list -l en');
all_pod_files_spelling_ok();

done_testing();
