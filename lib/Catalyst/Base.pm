package Catalyst::Base;

use strict;
use base qw/Class::Data::Inheritable Class::Accessor::Fast/;
use NEXT;

__PACKAGE__->mk_classdata('_config');

=head1 NAME

Catalyst::Base - Catalyst Universal Base Class

=head1 SYNOPSIS

    # lib/MyApp/Model/Something.pm
    package MyApp::Model::Something;

    use base 'Catalyst::Base';

    __PACKAGE__->config( foo => 'bar' );

    sub test {
        my $self = shift;
        return $self->{foo};
    }

    sub forward_to_me {
        my ( $self, $c ) = @_;
        $c->response->output( $self->{foo} );
    }
    
    1;

    # Methods can be a request step
    $c->forward(qw/MyApp::Model::Something forward_to_me/);
    MyApp->action( 'index.html' => \&MyApp::Model::Something::forward_to_me );

    # Or just methods
    print $c->comp('MyApp::Model::Something')->test;

    print $c->comp('MyApp::Model::Something')->{foo};

=head1 DESCRIPTION

This is the universal base class for Catalyst components
(Model/View/Controller).

It provides you with a generic new() for instantiation through Catalyst's
component loader with config() support and a process() method placeholder.

=head1 METHODS

=over 4

=item new($c)

=cut

sub new {
    my ( $self, $c ) = @_;
    return $self->NEXT::new( $self->config );
}

# remember to leave blank lines between the consecutive =item's
# otherwise the pod tools don't recognize the subsequent =items

=item $c->config

=item $c->config($hashref)

=item $c->config($key, $value, ...)

=cut

sub config {
    my $self = shift;
    $self->_config( {} ) unless $self->_config;
    if ( $_[0] ) {
        my $config = $_[1] ? {@_} : $_[0];
        while ( my ( $key, $val ) = each %$config ) {
            $self->_config->{$key} = $val;
        }
    }
    return $self->_config;
}

=item $c->process()

=cut

sub process { 1 }

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
