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

## thank to Brian
## http://bricas.vox.com/library/post/catalyst-exceptionclass.html

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

# Start the application
__PACKAGE__->setup;

=head1 NAME

TestAppClassExceptionSimpleTest - Catalyst based application

=head1 SYNOPSIS

    script/TestAppClassExceptionSipleTest_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<TestAppClassException::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Ferruccio Zamuner

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
