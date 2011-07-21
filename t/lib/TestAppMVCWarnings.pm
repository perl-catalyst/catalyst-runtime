package TestAppMVCWarnings;
use Moose;
extends 'Catalyst';
use Catalyst;

our @log_messages;

__PACKAGE__->config( name => 'TestAppMVCWarnings', root => '/some/dir', default_view => "DoesNotExist" );

__PACKAGE__->log(TestAppMVCWarnings::Log->new);

__PACKAGE__->setup;

package TestAppMVCWarnings::Log;
use Moose;
extends q/Catalyst::Log/;

sub warn { push(@TestAppMVCWarnings::log_messages, @_[1..$#_]); }

1;
