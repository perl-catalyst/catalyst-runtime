package TestAppClassExceptionSimpleTest::Exceptions;

use strict;
use warnings;

BEGIN {
    $Catalyst::Exception::CATALYST_EXCEPTION_CLASS = 'TestAppClassExceptionSimpleTest::Exception';

    my %classes = (
        'TestAppClassExceptionSimpleTest::Exception' => {
            description => 'Generic exception',
            alias       => 'throw'
        },
    );

    my @exports = grep { defined } map { $classes{ $_ }->{ alias } } keys %classes;

    require Exception::Class;
    require Sub::Exporter;

    Exception::Class->import(%classes);
    Sub::Exporter->import( -setup => { exports => \@exports  } );
}

package TestAppClassExceptionSimpleTest::Exception;

use strict;
use warnings;
no warnings 'redefine';

use HTTP::Headers ();
use HTTP::Status  ();
use Scalar::Util  qw( blessed );

sub status {
    return $_[0]->{status} ||= 500;
}

#########

package TestAppClassExceptionSimpleTest;

use strict;
use warnings;
use Scalar::Util ();
use Catalyst::Runtime '5.80';

use Catalyst qw/ -Debug /;

our $VERSION = '0.02';

__PACKAGE__->setup;

1;
