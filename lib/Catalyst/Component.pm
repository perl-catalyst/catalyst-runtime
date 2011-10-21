package Catalyst::Component;

use Moose;
use Class::MOP;
use Class::MOP::Object;
use Catalyst::Utils;
use Class::C3::Adopt::NEXT;
use Devel::InnerPackage ();
use MRO::Compat;
use mro 'c3';
use Scalar::Util 'blessed';
use namespace::clean -except => 'meta';

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

It provides you with a generic new() for component construction through Catalyst's
component loader with config() support and a process() method placeholder.

=cut

__PACKAGE__->mk_classdata('_plugins');
__PACKAGE__->mk_classdata('_config');

has catalyst_component_name => ( is => 'ro' ); # Cannot be required => 1 as context
                                       # class @ISA component - HATE
# Make accessor callable as a class method, as we need to call setup_actions
# on the application class, which we don't have an instance of, ewwwww
# Also, naughty modules like Catalyst::View::JSON try to write to _everything_,
# so spit a warning, ignore that (and try to do the right thing anyway) here..
around catalyst_component_name => sub {
    my ($orig, $self) = (shift, shift);
    Carp::cluck("Tried to write to the catalyst_component_name accessor - is your component broken or just mad? (Write ignored - using default value.)") if scalar @_;
    blessed($self) ? $self->$orig() || blessed($self) : $self;
};

sub BUILDARGS {
    my $class = shift;
    my $args = {};

    if (@_ == 1) {
        $args = $_[0] if ref($_[0]) eq 'HASH';
    } elsif (@_ == 2) { # is it ($app, $args) or foo => 'bar' ?
        if (blessed($_[0])) {
            $args = $_[1] if ref($_[1]) eq 'HASH';
        } elsif (Class::MOP::is_class_loaded($_[0]) &&
                $_[0]->isa('Catalyst') && ref($_[1]) eq 'HASH') {
            $args = $_[1];
        } else {
            $args = +{ @_ };
        }
    } elsif (@_ % 2 == 0) {
        $args = +{ @_ };
    }

    return $class->merge_config_hashes( $class->config, $args );
}

sub COMPONENT {
    my ( $class, $c ) = @_;

    # Temporary fix, some components does not pass context to constructor
    my $arguments = ( ref( $_[-1] ) eq 'HASH' ) ? $_[-1] : {};
    if ( my $next = $class->next::can ) {
      my ($next_package) = Class::MOP::get_code_info($next);
      warn "There is a COMPONENT method resolving after Catalyst::Component in ${next_package}.\n";
      warn "This behavior can no longer be supported, and so your application is probably broken.\n";
      warn "Your linearized isa hierarchy is: " . join(', ', @{ mro::get_linear_isa($class) }) . "\n";
      warn "Please see perldoc Catalyst::Upgrading for more information about this issue.\n";
    }
    return $class->new($c, $arguments);
}

sub config {
    my $self = shift;
    # Uncomment once sane to do so
    #Carp::cluck("config method called on instance") if ref $self;
    my $config = $self->_config || {};
    if (@_) {
        my $newconfig = { %{@_ > 1 ? {@_} : $_[0]} };
        $self->_config(
            $self->merge_config_hashes( $config, $newconfig )
        );
    } else {
        # this is a bit of a kludge, required to make
        # __PACKAGE__->config->{foo} = 'bar';
        # work in a subclass.
        # TODO maybe this should be a ClassData option?
        my $class = blessed($self) || $self;
        my $meta = Class::MOP::get_metaclass_by_name($class);
        unless (${ $meta->get_or_add_package_symbol('$_config') }) {
            # Call merge_hashes to ensure we deep copy the parent
            # config onto the subclass
            $self->_config( Catalyst::Utils::merge_hashes($config, {}) );
        }
    }
    return $self->_config;
}

sub merge_config_hashes {
    my ( $self, $lefthash, $righthash ) = @_;

    return Catalyst::Utils::merge_hashes( $lefthash, $righthash );
}

sub process {

    Catalyst::Exception->throw( message => ( ref $_[0] || $_[0] )
          . " did not override Catalyst::Component::process" );
}

sub expand_modules {
    my ($class, $component) = @_;
    return Devel::InnerPackage::list_packages( $component );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 METHODS

=head2 new($app, $arguments)

Called by COMPONENT to instantiate the component; should return an object
to be stored in the application's component hash.

=head2 COMPONENT

C<< my $component_instance = $component->COMPONENT($app, $arguments); >>

If this method is present (as it is on all Catalyst::Component subclasses),
it is called by Catalyst during setup_components with the application class
as $app and any config entry on the application for this component (for example,
in the case of MyApp::Controller::Foo this would be
C<< MyApp->config('Controller::Foo' => \%conf >>).

The arguments are expected to be a hashref and are merged with the
C<< __PACKAGE__->config >> hashref before calling C<< ->new >>
to instantiate the component.

You can override it in your components to do custom construction, using
something like this:

  sub COMPONENT {
      my ($class, $app, $args) = @_;
      $args = $class->merge_config_hashes($class->config, $args);
      return $class->new($app, $args);
  }

=head2 $c->config

=head2 $c->config($hashref)

=head2 $c->config($key, $value, ...)

Accessor for this component's config hash. Config values can be set as
key value pair, or you can specify a hashref. In either case the keys
will be merged with any existing config settings. Each component in
a Catalyst application has its own config hash.

The component's config hash is merged with any config entry on the
application for this component and passed to C<new()> (as mentioned
above at L</COMPONENT>). The common practice to access the merged
config is to use a Moose attribute for each config entry on the
receiving component.

=head2 $c->process()

This is the default method called on a Catalyst component in the dispatcher.
For instance, Views implement this action to render the response body
when you forward to them. The default is an abstract method.

=head2 $c->merge_config_hashes( $hashref, $hashref )

Merges two hashes together recursively, giving right-hand precedence.
Alias for the method in L<Catalyst::Utils>.

=head2 $c->expand_modules( $setup_component_config )

Return a list of extra components that this component has created. By default,
it just looks for a list of inner packages of this component

=cut

=head1 OPTIONAL METHODS

=head2 ACCEPT_CONTEXT($c, @args)

Catalyst components are normally initialized during server startup, either
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

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
