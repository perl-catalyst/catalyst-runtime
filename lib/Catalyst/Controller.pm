package Catalyst::Controller;

use Moose;
use Moose::Util qw/find_meta/;
use List::MoreUtils qw/uniq/;
use namespace::clean -except => 'meta';

BEGIN { extends qw/Catalyst::Component MooseX::MethodAttributes::Inheritable/; }

use MooseX::MethodAttributes;
use Catalyst::Exception;
use Catalyst::Utils;

with 'Catalyst::Component::ApplicationAttribute';

has path_prefix =>
    (
     is => 'rw',
     isa => 'Str',
     init_arg => 'path',
     predicate => 'has_path_prefix',
    );

has action_namespace =>
    (
     is => 'rw',
     isa => 'Str',
     init_arg => 'namespace',
     predicate => 'has_action_namespace',
    );

has actions =>
    (
     accessor => '_controller_actions',
     isa => 'HashRef',
     init_arg => undef,
    );

# ->config(actions => { '*' => ...
has _all_actions_attributes => (
    is       => 'ro',
    isa      => 'HashRef',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build__all_actions_attributes',
);

sub BUILD {
    my ($self, $args) = @_;
    my $action  = delete $args->{action}  || {};
    my $actions = delete $args->{actions} || {};
    my $attr_value = $self->merge_config_hashes($actions, $action);
    $self->_controller_actions($attr_value);

    # trigger lazy builder
    $self->_all_actions_attributes;
}

sub _build__all_actions_attributes {
    my ($self) = @_;
    delete $self->_controller_actions->{'*'} || {};
}

=head1 NAME

Catalyst::Controller - Catalyst Controller base class

=head1 SYNOPSIS

  package MyApp::Controller::Search
  use base qw/Catalyst::Controller/;

  sub foo : Local {
    my ($self,$c,@args) = @_;
    ...
  } # Dispatches to /search/foo

=head1 DESCRIPTION

Controllers are where the actions in the Catalyst framework
reside. Each action is represented by a function with an attribute to
identify what kind of action it is. See the L<Catalyst::Dispatcher>
for more info about how Catalyst dispatches to actions.

=cut

#I think both of these could be attributes. doesn't really seem like they need
#to ble class data. i think that attributes +default would work just fine
__PACKAGE__->mk_classdata($_) for qw/_dispatch_steps _action_class/;

__PACKAGE__->_dispatch_steps( [qw/_BEGIN _AUTO _ACTION/] );
__PACKAGE__->_action_class('Catalyst::Action');


sub _DISPATCH : Private {
    my ( $self, $c ) = @_;

    foreach my $disp ( @{ $self->_dispatch_steps } ) {
        last unless $c->forward($disp);
    }

    $c->forward('_END');
}

sub _BEGIN : Private {
    my ( $self, $c ) = @_;
    my $begin = ( $c->get_actions( 'begin', $c->namespace ) )[-1];
    return 1 unless $begin;
    $begin->dispatch( $c );
    return !@{ $c->error };
}

sub _AUTO : Private {
    my ( $self, $c ) = @_;
    my @auto = $c->get_actions( 'auto', $c->namespace );
    foreach my $auto (@auto) {
        $auto->dispatch( $c );
        return 0 unless $c->state;
    }
    return 1;
}

sub _ACTION : Private {
    my ( $self, $c ) = @_;
    if (   ref $c->action
        && $c->action->can('execute')
        && defined $c->req->action )
    {
        $c->action->dispatch( $c );
    }
    return !@{ $c->error };
}

sub _END : Private {
    my ( $self, $c ) = @_;
    my $end = ( $c->get_actions( 'end', $c->namespace ) )[-1];
    return 1 unless $end;
    $end->dispatch( $c );
    return !@{ $c->error };
}

sub action_for {
    my ( $self, $name ) = @_;
    my $app = ($self->isa('Catalyst') ? $self : $self->_application);
    return $app->dispatcher->get_action($name, $self->action_namespace);
}

#my opinion is that this whole sub really should be a builder method, not
#something that happens on every call. Anyone else disagree?? -- groditi
## -- apparently this is all just waiting for app/ctx split
around action_namespace => sub {
    my $orig = shift;
    my ( $self, $c ) = @_;

    my $class = ref($self) || $self;
    my $appclass = ref($c) || $c;
    if( ref($self) ){
        return $self->$orig if $self->has_action_namespace;
    } else {
        return $class->config->{namespace} if exists $class->config->{namespace};
    }

    my $case_s;
    if( $c ){
        $case_s = $appclass->config->{case_sensitive};
    } else {
        if ($self->isa('Catalyst')) {
            $case_s = $class->config->{case_sensitive};
        } else {
            if (ref $self) {
                $case_s = ref($self->_application)->config->{case_sensitive};
            } else {
                confess("Can't figure out case_sensitive setting");
            }
        }
    }

    my $namespace = Catalyst::Utils::class2prefix($self->catalyst_component_name, $case_s) || '';
    $self->$orig($namespace) if ref($self);
    return $namespace;
};

#Once again, this is probably better written as a builder method
around path_prefix => sub {
    my $orig = shift;
    my $self = shift;
    if( ref($self) ){
      return $self->$orig if $self->has_path_prefix;
    } else {
      return $self->config->{path} if exists $self->config->{path};
    }
    my $namespace = $self->action_namespace(@_);
    $self->$orig($namespace) if ref($self);
    return $namespace;
};

sub get_action_methods {
    my $self = shift;
    my $meta = find_meta($self) || confess("No metaclass setup for $self");
    confess(
        sprintf "Metaclass %s for %s cannot support register_actions.",
            ref $meta, $meta->name,
    ) unless $meta->can('get_nearest_methods_with_attributes');
    my @methods = $meta->get_nearest_methods_with_attributes;

    # actions specified via config are also action_methods
    push(
        @methods,
        map {
            $meta->find_method_by_name($_)
                || confess( sprintf 'Action "%s" is not available from controller %s',
                            $_, ref $self )
        } keys %{ $self->_controller_actions }
    ) if ( ref $self );
    return uniq @methods;
}


sub register_actions {
    my ( $self, $c ) = @_;
    $self->register_action_methods( $c, $self->get_action_methods );
}

sub register_action_methods {
    my ( $self, $c, @methods ) = @_;
    my $class = $self->catalyst_component_name;
    #this is still not correct for some reason.
    my $namespace = $self->action_namespace($c);

    # FIXME - fugly
    if (!blessed($self) && $self eq $c && scalar(@methods)) {
        my @really_bad_methods = grep { ! /^_(DISPATCH|BEGIN|AUTO|ACTION|END)$/ } map { $_->name } @methods;
        if (scalar(@really_bad_methods)) {
            $c->log->warn("Action methods (" . join(', ', @really_bad_methods) . ") found defined in your application class, $self. This is deprecated, please move them into a Root controller.");
        }
    }

    foreach my $method (@methods) {
        my $name = $method->name;
        # Horrible hack! All method metaclasses should have an attributes
        # method, core Moose bug - see r13354.
        my $attributes = $method->can('attributes') ? $method->attributes : [];
        my $attrs = $self->_parse_attrs( $c, $name, @{ $attributes } );
        if ( $attrs->{Private} && ( keys %$attrs > 1 ) ) {
            $c->log->debug( 'Bad action definition "'
                  . join( ' ', @{ $attributes } )
                  . qq/" for "$class->$name"/ )
              if $c->debug;
            next;
        }
        my $reverse = $namespace ? "${namespace}/${name}" : $name;
        my $action = $self->create_action(
            name       => $name,
            code       => $method->body,
            reverse    => $reverse,
            namespace  => $namespace,
            class      => $class,
            attributes => $attrs,
        );

        $c->dispatcher->register( $c, $action );
    }
}

sub action_class {
    my $self = shift;
    my %args = @_;

    my $class = (exists $args{attributes}{ActionClass}
        ? $args{attributes}{ActionClass}[0]
        : $self->_action_class);

    Class::MOP::load_class($class);
    return $class;
}

sub create_action {
    my $self = shift;
    my %args = @_;

    my $class = $self->action_class(%args);
    my $action_args = $self->config->{action_args};

    my %extra_args = (
        %{ $action_args->{'*'}           || {} },
        %{ $action_args->{ $args{name} } || {} },
    );

    return $class->new({ %extra_args, %args });
}

sub _parse_attrs {
    my ( $self, $c, $name, @attrs ) = @_;

    my %raw_attributes;

    foreach my $attr (@attrs) {

        # Parse out :Foo(bar) into Foo => bar etc (and arrayify)

        if ( my ( $key, $value ) = ( $attr =~ /^(.*?)(?:\(\s*(.+?)\s*\))?$/ ) )
        {

            if ( defined $value ) {
                ( $value =~ s/^'(.*)'$/$1/ ) || ( $value =~ s/^"(.*)"/$1/ );
            }
            push( @{ $raw_attributes{$key} }, $value );
        }
    }

    my ($actions_config, $all_actions_config);
    if( ref($self) ) {
        $actions_config = $self->_controller_actions;
        # No, you're not getting actions => { '*' => ... } with actions in MyApp.
        $all_actions_config = $self->_all_actions_attributes;
    } else {
        my $cfg = $self->config;
        $actions_config = $self->merge_config_hashes($cfg->{actions}, $cfg->{action});
        $all_actions_config = {};
    }

    %raw_attributes = (
        %raw_attributes,
        # Note we deep copy array refs here to stop crapping on config
        # when attributes are parsed. RT#65463
        exists $actions_config->{$name} ? map { ref($_) eq 'ARRAY' ? [ @$_ ] : $_ } %{ $actions_config->{$name } } : (),
    );

    # Private actions with additional attributes will raise a warning and then
    # be ignored. Adding '*' arguments to the default _DISPATCH / etc. methods,
    # which are Private, will prevent those from being registered. They should
    # probably be turned into :Actions instead, or we might want to otherwise
    # disambiguate between those built-in internal actions and user-level
    # Private ones.
    %raw_attributes = (%{ $all_actions_config }, %raw_attributes)
        unless $raw_attributes{Private};

    my %final_attributes;

    foreach my $key (keys %raw_attributes) {

        my $raw = $raw_attributes{$key};

        foreach my $value (ref($raw) eq 'ARRAY' ? @$raw : $raw) {

            my $meth = "_parse_${key}_attr";
            if ( my $code = $self->can($meth) ) {
                ( $key, $value ) = $self->$code( $c, $name, $value );
            }
            push( @{ $final_attributes{$key} }, $value );
        }
    }

    return \%final_attributes;
}

sub _parse_Global_attr {
    my ( $self, $c, $name, $value ) = @_;
    return $self->_parse_Path_attr( $c, $name, "/$name" );
}

sub _parse_Absolute_attr { shift->_parse_Global_attr(@_); }

sub _parse_Local_attr {
    my ( $self, $c, $name, $value ) = @_;
    return $self->_parse_Path_attr( $c, $name, $name );
}

sub _parse_Relative_attr { shift->_parse_Local_attr(@_); }

sub _parse_Path_attr {
    my ( $self, $c, $name, $value ) = @_;
    $value = '' if !defined $value;
    if ( $value =~ m!^/! ) {
        return ( 'Path', $value );
    }
    elsif ( length $value ) {
        return ( 'Path', join( '/', $self->path_prefix($c), $value ) );
    }
    else {
        return ( 'Path', $self->path_prefix($c) );
    }
}

sub _parse_Regex_attr {
    my ( $self, $c, $name, $value ) = @_;
    return ( 'Regex', $value );
}

sub _parse_Regexp_attr { shift->_parse_Regex_attr(@_); }

sub _parse_LocalRegex_attr {
    my ( $self, $c, $name, $value ) = @_;
    unless ( $value =~ s/^\^// ) { $value = "(?:.*?)$value"; }

    my $prefix = $self->path_prefix( $c );
    $prefix .= '/' if length( $prefix );

    return ( 'Regex', "^${prefix}${value}" );
}

sub _parse_LocalRegexp_attr { shift->_parse_LocalRegex_attr(@_); }

sub _parse_Chained_attr {
    my ($self, $c, $name, $value) = @_;

    if (defined($value) && length($value)) {
        if ($value eq '.') {
            $value = '/'.$self->action_namespace($c);
        } elsif (my ($rel, $rest) = $value =~ /^((?:\.{2}\/)+)(.*)$/) {
            my @parts = split '/', $self->action_namespace($c);
            my @levels = split '/', $rel;

            $value = '/'.join('/', @parts[0 .. $#parts - @levels], $rest);
        } elsif ($value !~ m/^\//) {
            my $action_ns = $self->action_namespace($c);

            if ($action_ns) {
                $value = '/'.join('/', $action_ns, $value);
            } else {
                $value = '/'.$value; # special case namespace '' (root)
            }
        }
    } else {
        $value = '/'
    }

    return Chained => $value;
}

sub _parse_ChainedParent_attr {
    my ($self, $c, $name, $value) = @_;
    return $self->_parse_Chained_attr($c, $name, '../'.$name);
}

sub _parse_PathPrefix_attr {
    my ( $self, $c ) = @_;
    return PathPart => $self->path_prefix($c);
}

sub _parse_ActionClass_attr {
    my ( $self, $c, $name, $value ) = @_;
    my $appname = $self->_application;
    $value = Catalyst::Utils::resolve_namespace($appname . '::Action', $self->_action_class, $value);
    return ( 'ActionClass', $value );
}

sub _parse_MyAction_attr {
    my ( $self, $c, $name, $value ) = @_;

    my $appclass = Catalyst::Utils::class2appclass($self);
    $value = "${appclass}::Action::${value}";

    return ( 'ActionClass', $value );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 CONFIGURATION

Like any other L<Catalyst::Component>, controllers have a config hash,
accessible through $self->config from the controller actions.  Some
settings are in use by the Catalyst framework:

=head2 namespace

This specifies the internal namespace the controller should be bound
to. By default the controller is bound to the URI version of the
controller name. For instance controller 'MyApp::Controller::Foo::Bar'
will be bound to 'foo/bar'. The default Root controller is an example
of setting namespace to '' (the null string).

=head2 path

Sets 'path_prefix', as described below.

=head2 action

Allows you to set the attributes that the dispatcher creates actions out of.
This allows you to do 'rails style routes', or override some of the
attribute definitions of actions composed from Roles.
You can set arguments globally (for all actions of the controller) and
specifically (for a single action).

    __PACKAGE__->config(
        action => {
            '*' => { Chained => 'base', Args => 0  },
            base => { Chained => '/', PathPart => '', CaptureArgs => 0 },
        },
     );

In the case above every sub in the package would be made into a Chain
endpoint with a URI the same as the sub name for each sub, chained
to the sub named C<base>. Ergo dispatch to C</example> would call the
C<base> method, then the C<example> method.

=head2 action_args

Allows you to set constructor arguments on your actions. You can set arguments
globally and specifically (as above).
This is particularly useful when using C<ActionRole>s
(L<Catalyst::Controller::ActionRole>) and custom C<ActionClass>es.

    __PACKAGE__->config(
        action_args => {
            '*' => { globalarg1 => 'hello', globalarg2 => 'goodbye' },
            'specific_action' => { customarg => 'arg1' },
        },
     );

In the case above the action class associated with C<specific_action> would get
passed the following arguments, in addition to the normal action constructor
arguments, when it is instantiated:

  (globalarg1 => 'hello', globalarg2 => 'goodbye', customarg => 'arg1')

=head1 METHODS

=head2 BUILDARGS ($app, @args)

From L<Catalyst::Component::ApplicationAttribute>, stashes the application
instance as $self->_application.

=head2 $self->action_for('name')

Returns the Catalyst::Action object (if any) for a given method name
in this component.

=head2 $self->action_namespace($c)

Returns the private namespace for actions in this component. Defaults
to a value from the controller name (for
e.g. MyApp::Controller::Foo::Bar becomes "foo/bar") or can be
overridden from the "namespace" config key.


=head2 $self->path_prefix($c)

Returns the default path prefix for :PathPrefix, :Local, :LocalRegex and
relative :Path actions in this component. Defaults to the action_namespace or
can be overridden from the "path" config key.

=head2 $self->register_actions($c)

Finds all applicable actions for this component, creates
Catalyst::Action objects (using $self->create_action) for them and
registers them with $c->dispatcher.

=head2 $self->get_action_methods()

Returns a list of L<Moose::Meta::Method> objects, doing the
L<MooseX::MethodAttributes::Role::Meta::Method> role, which are the set of
action methods for this package.

=head2 $self->register_action_methods($c, @methods)

Creates action objects for a set of action methods using C< create_action >,
and registers them with the dispatcher.

=head2 $self->action_class(%args)

Used when a controller is creating an action to determine the correct base
action class to use.

=head2 $self->create_action(%args)

Called with a hash of data to be use for construction of a new
Catalyst::Action (or appropriate sub/alternative class) object.

=head2 $self->_application

=head2 $self->_app

Returns the application instance stored by C<new()>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
