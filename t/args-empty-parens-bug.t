use warnings;
use strict;
use Test::More;
use FindBin qw< $Bin >;
use lib "$Bin/lib";
use constant App => 'TestAppArgsEmptyParens';
use Catalyst::Test App;

{
    my $res = request('/chain_base/args/foo/bar');
    is $res->content, 'Args', "request '/chain_base/args/foo/bar'";
}

{
    my $res = request('/chain_base/args_empty/foo/bar');
    is $res->content, 'Args()', "request '/chain_base/args_empty/foo/bar'";
}

eval { App->dispatcher->dispatch_type('Chained')->list(App) };
ok !$@, "didn't die"
    or diag "Died with: $@";
like $TestLogger::LOGS[-1], qr{/args\s*\Q(...)\E};
like $TestLogger::LOGS[-1], qr{/args_empty\s*\Q(...)\E};

done_testing;

__END__

