use strict;
use warnings;

package TestAppViewWarnings;

use Catalyst;

our @log_messages;

__PACKAGE__->config( name => 'TestAppWarnings', root => '/some/dir', default_view => "DoesNotExist" );

__PACKAGE__->log(TestAppViewWarnings::Log->new);

__PACKAGE__->setup;

package TestAppViewWarnings::Log;

use base qw/Catalyst::Log/;
sub warn { push(@TestAppViewWarnings::log_messages, @_[1..$#_]); }

1;

