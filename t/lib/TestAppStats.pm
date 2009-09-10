use strict;
use warnings;

package TestAppStats;

use Catalyst qw/
    -Stats=1
/;

our $VERSION = '0.01';
our @log_messages;

__PACKAGE__->config( name => 'TestAppStats', root => '/some/dir' );

__PACKAGE__->log(TestAppStats::Log->new);

__PACKAGE__->setup;

package TestAppStats::Log;
use base qw/Catalyst::Log/;

sub info { push(@TestAppStats::log_messages, @_); }
sub debug { push(@TestAppStats::log_messages, @_); }
