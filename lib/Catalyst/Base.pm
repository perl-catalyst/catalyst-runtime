package Catalyst::Base;

use strict;
use base qw/Catalyst::AttrContainer Class::Accessor::Fast/;

use Catalyst::Exception;
use NEXT;

__PACKAGE__->mk_classdata($_) for qw/_config/;

sub _DISPATCH :Private {
    my ( $self, $c ) = @_;
    my @containers = $c->dispatcher->get_containers( $c->namespace );
    my %actions;
    foreach my $name (qw/begin auto end/) {

        # Go down the container list representing each part of the
        # current namespace inheritance tree, grabbing the actions hash
        # of the ActionContainer object and looking for actions of the
        # appropriate name registered to the namespace

        $actions{$name} = [
            map    { $_->{$name} }
              grep { exists $_->{$name} }
              map  { $_->actions } @containers
        ];
    }

    # Errors break the normal flow and the end action is instantly run
    my $error = 0;

    # Execute last begin
    $c->state(1);
    if ( my $begin = @{ $actions{begin} }[-1] ) {
        $begin->execute($c);
        $error++ if scalar @{ $c->error };
    }

    # Execute the auto chain
    my $autorun = 0;
    for my $auto ( @{ $actions{auto} } ) {
        last if $error;
        $autorun++;
        $auto->execute($c);
        $error++ if scalar @{ $c->error };
        last unless $c->state;
    }

    # Execute the action or last default
    my $mkay = $autorun ? $c->state ? 1 : 0 : 1;
    if ($mkay) {
        unless ($error) {
            $c->action->execute($c);
            $error++ if scalar @{ $c->error };
        }
    }

    # Execute last end
    if ( my $end = @{ $actions{end} }[-1] ) {
        $end->execute($c);
    }
}

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
 
    # Temporary fix, some components does not pass context to constructor
    my $arguments = ( ref( $_[-1] ) eq 'HASH' ) ? $_[-1] : {};

    return $self->NEXT::new( { %{ $self->config }, %{ $arguments } } );
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
    if (@_) {
        my $config = @_ > 1 ? {@_} : $_[0];
        while ( my ( $key, $val ) = each %$config ) {
            $self->_config->{$key} = $val;
        }
    }
    return $self->_config;
}

=item $c->process()

=cut

sub process {

    Catalyst::Exception->throw( 
        message => ( ref $_[0] || $_[0] ) . " did not override Catalyst::Base::process"
    );
}

=item FETCH_CODE_ATTRIBUTES

=item MODIFY_CODE_ATTRIBUTES

=back

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Marcus Ramberg, C<mramberg@cpan.org>
Matt S Trout, C<mst@shadowcatsystems.co.uk>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
