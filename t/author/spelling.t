use strict;
use warnings;
use Test::More;
use Test::Spelling;

add_stopwords(qw(
    undef env regex rethrow rethrows stringifies CPAN STDERR SIGCHLD
    roadmap wishlist refactor refactored Runtime pluggable pluggability hoc apis
    fastcgi nginx IIS middlewares
    ctx _application MyApp restarter httponly Utils stash's unescapes
    dispatchtype dispatchtypes redispatch redispatching
    CaptureArgs ChainedParent PathPart PathPrefix
    BUILDARGS metaclass
    filename tempname
    wiki bitmask uri url urls dir hostname http https IP SSL
));
set_spell_cmd('aspell list -l en_GB');
all_pod_files_spelling_ok();

done_testing();
