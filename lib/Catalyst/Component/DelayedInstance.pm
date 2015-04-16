package Catalyst::Component::DelayedInstance;

use Moose::Role;

around 'COMPONENT', sub {
  my ($orig, $class, $app, $conf) = @_;
  my $method = $class->can('build_delayed_instance') ?
    'build_delayed_instance' : 'COMPONENT';

  return bless sub { my $c = shift; $class->$method($app, $conf) }, $class;
};

our $SINGLE;

sub ACCEPT_CONTEXT {
  my ($self, $c, @args) = @_;
  $c->log->warn("Component ${\$self->catalyst_component_name} cannot be called with arguments")
    if $c->debug and scalar(@args) > 0;

  return $SINGLE ||= $self->();
}

sub AUTOLOAD {
  my ($self, @args) = @_;
  my $method = our $AUTOLOAD;
  $method =~ s/.*:://;

  warn $method;
  use Devel::Dwarn;
  Dwarn \@args;
  
  return ($SINGLE ||= $self->())->$method(@args);
}

1;

=head1 NAME

Catalyst::Component::DelayedInstance - Moose Role for components which setup 

=head1 SYNOPSIS

    package MyApp::Model::Foo;

    use Moose;
    extends 'Catalyst::Model';
    with 'Catalyst::Component::DelayedInstance';

    sub build_per_application_instance {
      my ($class, $app, $config) = @_;

      $config->{bar} = $app->model("Baz");
      return $class->new($config);
    }    

=head1 DESCRIPTION

Sometimes you want an application scoped component that nevertheless needs other
application components as part of its setup.  In the past this was not reliable
since Application scoped components are setup in linear order.  You could not
call $app->model in a COMPONENT method and expect 'Foo' to be there.  This role
defers creating the application scoped instance until after your application is
fully setup.  This means you can now assume your other application scoped components
(components that do COMPONENT but not ACCEPT_CONTEXT) are available as dependencies.

Please note this means that your instance is not created until the first time its
called in a request.  As a result any errors with configuration will not show up
until later in runtime.  So there is a larger burden on your testing to make sure
your application startup and runtime is accurate.  Also note that even though your
instance creation is deferred to request time, the request context is NOT given,
but the application is (this means that you cannot depend on components that do
ACCEPT_CONTEXT, since you don't have one...).

=head1 ATTRIBUTES

=head1 METHODS

=head2 ACCEPT_CONTEXT

=head2 AUTOLOAD

=head1 SEE ALSO

L<Catalyst::Component>,

=head1 AUTHORS

See L<Catalyst>.

=head1 COPYRIGHT

See L<Catalyst>.

=cut
