package Catalyst::Test;

use strict;
use UNIVERSAL::require;

$ENV{CATALYST_ENGINE} = 'Test';

=head1 NAME

Catalyst::Test - Test Catalyst applications

=head1 SYNOPSIS

    # Helper
    script/test.pl

    # Tests
    use Catalyst::Test 'TestApp';
    request('index.html');
    get('index.html');

    # Tests with inline apps need to use Catalyst::Engine::Test
    package TestApp;

    use Catalyst qw[-Engine=Test];

    __PACKAGE__->action(
        foo => sub {
            my ( $self, $c ) = @_;
            $c->res->output('bar');
        }
    );

    package main;

    use Test::More tests => 1;
    use Catalyst::Test 'TestApp';

    ok( get('/foo') =~ /bar/ );


=head1 DESCRIPTION

Test Catalyst applications.

=head2 METHODS

=head3 get

Returns the content.

    my $content = get('foo/bar?test=1');

=head3 request

Returns a C<HTTP::Response> object.

    my $res =request('foo/bar?test=1');

=cut

sub import {
    my $self = shift;
    if ( my $class = shift ) {
        $class->require;
        unless ( $INC{'Test/Builder.pm'} ) {
            die qq/Couldn't load "$class", "$@"/ if $@;
        }

        no strict 'refs';
        my $caller = caller(0);
        *{"$caller\::request"} = sub { $class->run(@_) };
        *{"$caller\::get"}     = sub { $class->run(@_)->content };
    }
}

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
