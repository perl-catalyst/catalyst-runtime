package Catalyst::Test;

use strict;
use UNIVERSAL::require;

require Catalyst;

my $class;

=head1 NAME

Catalyst::Test - Test Catalyst applications

=head1 SYNOPSIS

    # Helper
    script/test.pl

    # Tests
    use Catalyst::Test 'TestApp';
    request('index.html');
    get('index.html');

    # Request
    perl -MCatalyst::Test=MyApp -e1 index.html

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

{
    no warnings;
    CHECK {
        if ( ( caller(0) )[1] eq '-e' ) {
            print request( $ARGV[0] || 'http://localhost' )->content;
        }
    }
}

sub import {
    my $self = shift;
    if ( $class = shift ) {
        $class->require;
        unless ( $INC{'Test/Builder.pm'} ) {
            die qq/Couldn't load "$class", "$@"/ if $@;
        }

        no strict 'refs';

        unless ( $class->engine->isa('Catalyst::Engine::Test') ) {
            require Catalyst::Engine::Test;
            splice( @{"$class\::ISA"}, @{"$class\::ISA"} - 1,
                0, 'Catalyst::Engine::Test' );
        }

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
