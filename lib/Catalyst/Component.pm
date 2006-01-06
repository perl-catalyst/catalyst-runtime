package Catalyst::Component;

use strict;
use base qw/Class::Accessor::Fast Class::Data::Inheritable/;
use NEXT;

__PACKAGE__->mk_classdata($_) for qw/_config/;

=head1 NAME

Catalyst::Component - Catalyst Component Base Class

=head1 SYNOPSIS

    # lib/MyApp/Model/Something.pm
    package MyApp::Model::Something;

    use base 'Catalyst::Component';

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

    # Or just methods
    print $c->comp('MyApp::Model::Something')->test;

    print $c->comp('MyApp::Model::Something')->{foo};

=head1 DESCRIPTION

This is the universal base class for Catalyst components
(Model/View/Controller).

It provides you with a generic new() for instantiation through Catalyst's
component loader with config() support and a process() method placeholder.

=head1 METHODS

=head2 new($c)

=cut

sub new {
    my ( $self, $c ) = @_;

    # Temporary fix, some components does not pass context to constructor
    my $arguments = ( ref( $_[-1] ) eq 'HASH' ) ? $_[-1] : {};

    return $self->NEXT::new( { %{ $self->config }, %{$arguments} } );
}

=head2 COMPONENT($c)

=cut

sub COMPONENT {
    my ( $self, $c ) = @_;

    # Temporary fix, some components does not pass context to constructor
    my $arguments = ( ref( $_[-1] ) eq 'HASH' ) ? $_[-1] : {};

    if ( my $new = $self->NEXT::COMPONENT( $c, $arguments ) ) {
        return $new;
    }
    else {
        if ( my $new = $self->new( $c, $arguments ) ) {
            return $new;
        }
        else {
            my $class = ref $self || $self;
            my $new = { %{ $self->config }, %{$arguments} };
            return bless $new, $class;
        }
    }
}

# remember to leave blank lines between the consecutive =head2's
# otherwise the pod tools don't recognize the subsequent =head2s

=head2 $c->config

=head2 $c->config($hashref)

=head2 $c->config($key, $value, ...)

=cut

sub config {
    my $self = shift;
    $self->_config( {} ) unless $self->_config;
    if (@_) {
        my $config = @_ > 1 ? {@_} : $_[0];
        while ( my ( $key, $val ) = each %$config ) {
            $self->_config->{$key} = $val;
        }
    }
    return $self->_config;
}

=head2 $c->process()

=cut

sub process {

    Catalyst::Exception->throw( message => ( ref $_[0] || $_[0] )
          . " did not override Catalyst::Component::process" );
}

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Model>, L<Catalyst::View>, L<Catalyst::Controller>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Marcus Ramberg, C<mramberg@cpan.org>
Matt S Trout, C<mst@shadowcatsystems.co.uk>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
