package Catalyst::Component;

use Moose;
use Class::MOP;
use Class::MOP::Object;
use MooseX::Adopt::Class::Accessor::Fast;
use Catalyst::Utils;
use Class::C3::Adopt::NEXT;
use MRO::Compat;
use mro 'c3';

with 'MooseX::Emulate::Class::Accessor::Fast';
with 'Catalyst::ClassData';


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

=cut

__PACKAGE__->mk_classdata('_plugins');
__PACKAGE__->mk_classdata('_config');

sub BUILDARGS {
    my ($self) = @_;
    
    # Temporary fix, some components does not pass context to constructor
    my $arguments = ( ref( $_[-1] ) eq 'HASH' ) ? $_[-1] : {};

    my $args =  $self->merge_config_hashes( $self->config, $arguments );
    
    return $args;
}

sub COMPONENT {
    my ( $self, $c ) = @_;

    # Temporary fix, some components does not pass context to constructor
    my $arguments = ( ref( $_[-1] ) eq 'HASH' ) ? $_[-1] : {};
    if( my $next = $self->next::can ){
      my $class = blessed $self || $self;
      my ($next_package) = Class::MOP::get_code_info($next);
      warn "There is a COMPONENT method resolving after Catalyst::Component in ${next_package}. This behavior is deprecated and will stop working in future releases.";
      return $next->($self, $arguments);
    }
    return $self->new($c, $arguments);
}

sub config {
    my $self = shift;
    my $config = $self->_config || {};
    if (@_) {
        my $newconfig = { %{@_ > 1 ? {@_} : $_[0]} };
        $self->_config(
            $self->merge_config_hashes( $config, $newconfig )
        );
    } else {
        # this is a bit of a kludge, required to make
        # __PACKAGE__->config->{foo} = 'bar';
        # work in a subclass. If we don't have the package symbol in the
        # current class we know we need to copy up to ours, which calling
        # the setter will do for us.
        my $meta = $self->Class::MOP::Object::meta();
        unless ($meta->has_package_symbol('$_config')) {

            $config = $self->merge_config_hashes( $config, {} );
            $self->_config( $config );
        }
    }
    return $config;
}

sub merge_config_hashes {
    my ( $self, $lefthash, $righthash ) = @_;

    return Catalyst::Utils::merge_hashes( $lefthash, $righthash );
}

sub process {

    Catalyst::Exception->throw( message => ( ref $_[0] || $_[0] )
          . " did not override Catalyst::Component::process" );
}

no Moose;

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 METHODS

=head2 new($c, $arguments)

Called by COMPONENT to instantiate the component; should return an object
to be stored in the application's component hash.

=head2 COMPONENT($c, $arguments)

If this method is present (as it is on all Catalyst::Component subclasses,
it is called by Catalyst during setup_components with the application class
as $c and any config entry on the application for this component (for example,
in the case of MyApp::Controller::Foo this would be
MyApp->config->{'Controller::Foo'}). The arguments are expected to be a 
hashref and are merged with the __PACKAGE__->config hashref before calling 
->new to instantiate the component.

=head2 $c->config

=head2 $c->config($hashref)

=head2 $c->config($key, $value, ...)

Accessor for this component's config hash. Config values can be set as 
key value pair, or you can specify a hashref. In either case the keys
will be merged with any existing config settings. Each component in 
a Catalyst application has it's own config hash.

=head2 $c->process()

This is the default method called on a Catalyst component in the dispatcher.
For instance, Views implement this action to render the response body 
when you forward to them. The default is an abstract method.

=head2 $c->merge_config_hashes( $hashref, $hashref )

Merges two hashes together recursively, giving right-hand precedence.
Alias for the method in L<Catalyst::Utils>.

=head1 OPTIONAL METHODS

=head2 ACCEPT_CONTEXT($c, @args)

Catalyst components are normally initalized during server startup, either
as a Class or a Instance. However, some components require information about
the current request. To do so, they can implement an ACCEPT_CONTEXT method.

If this method is present, it is called during $c->comp/controller/model/view
with the current $c and any additional args (e.g. $c->model('Foo', qw/bar baz/)
would cause your MyApp::Model::Foo instance's ACCEPT_CONTEXT to be called with
($c, 'bar', 'baz')) and the return value of this method is returned to the
calling code in the application rather than the component itself.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Model>, L<Catalyst::View>, L<Catalyst::Controller>.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
