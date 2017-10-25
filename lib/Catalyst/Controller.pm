package Catalyst::Controller;

use Moose;
use Class::MOP;
use Class::Load ':all';
use String::RewritePrefix;
use Moose::Util qw/find_meta/;
use List::Util qw/first uniq/;
use namespace::clean -except => 'meta';

BEGIN {
    extends qw/Catalyst::Component/;
    with qw/MooseX::MethodAttributes::Role::AttrContainer::Inheritable/;
}

use MooseX::MethodAttributes;
use Catalyst::Exception;
use Catalyst::Utils;

with 'Catalyst::Component::ApplicationAttribute';

has path_prefix => (
    is        => 'rw',
    isa       => 'Str',
    init_arg  => 'path',
    predicate => 'has_path_prefix',
);

has action_namespace => (
    is        => 'rw',
    isa       => 'Str',
    init_arg  => 'namespace',
    predicate => 'has_action_namespace',
);

has actions => (
    accessor => '_controller_actions',
    isa      => 'HashRef',
    init_arg => undef,
);

has _action_role_args => (
    traits     => [qw(Array)],
    isa        => 'ArrayRef[Str]',
    init_arg   => 'action_roles',
    default    => sub { [] },
    handles    => {
        _action_role_args => 'elements',
    },
);

has _action_roles => (
    traits     => [qw(Array)],
    isa        => 'ArrayRef[RoleName]',
    init_arg   => undef,
    lazy       => 1,
    builder    => '_build__action_roles',
    handles    => {
        _action_roles => 'elements',
    },
);

has action_args => (is => 'ro');

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
    $self->_action_roles;
}

sub _build__action_roles {
    my $self = shift;
    my @roles = $self->_expand_role_shortname($self->_action_role_args);
    load_class($_) for @roles;
    return \@roles;
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
#to be class data. i think that attributes +default would work just fine
__PACKAGE__->mk_classdata($_) for qw/_dispatch_steps _action_class _action_role_prefix/;

__PACKAGE__->_dispatch_steps( [qw/_BEGIN _AUTO _ACTION/] );
__PACKAGE__->_action_class('Catalyst::Action');
__PACKAGE__->_action_role_prefix([ 'Catalyst::ActionRole::' ]);


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
    #If there is an error, all bets off
    if( @{ $c->error }) {
      return !@{ $c->error };
    } else {
      return $c->state || 1;
    }
}

sub _AUTO : Private {
    my ( $self, $c ) = @_;
    my @auto = $c->get_actions( 'auto', $c->namespace );
    foreach my $auto (@auto) {
        # We FORCE the auto action user to explicitly return
        # true.  We need to do this since there's some auto
        # users (Catalyst::Authentication::Credential::HTTP) that
        # actually do a detach instead.  
        $c->state(0);
        $auto->dispatch( $c );
        return 0 unless $c->state;
    }
    return $c->state || 1;
}

sub _ACTION : Private {
    my ( $self, $c ) = @_;
    if (   ref $c->action
        && $c->action->can('execute')
        && defined $c->req->action )
    {
        $c->action->dispatch( $c );
    }
    #If there is an error, all bets off
    if( @{ $c->error }) {
      return !@{ $c->error };
    } else {
      return $c->state || 1;
    }
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
            $c->log->warn( 'Bad action definition "'
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

sub _apply_action_class_roles {
    my ($self, $class, @roles) = @_;

    load_class($_) for @roles;
    my $meta = Moose::Meta::Class->initialize($class)->create_anon_class(
        superclasses => [$class],
        roles        => \@roles,
        cache        => 1,
    );
    $meta->add_method(meta => sub { $meta });

    return $meta->name;
}

sub action_class {
    my $self = shift;
    my %args = @_;

    my $class = (exists $args{attributes}{ActionClass}
        ? $args{attributes}{ActionClass}[0]
        : $self->_action_class);

    load_class($class);
    return $class;
}

sub create_action {
    my $self = shift;
    my %args = @_;

    my $class = $self->action_class(%args);

    load_class($class);
    Moose->init_meta(for_class => $class)
        unless Class::MOP::does_metaclass_exist($class);

    unless ($args{name} =~ /^_(DISPATCH|BEGIN|AUTO|ACTION|END)$/) {
       my @roles = $self->gather_action_roles(%args);
       push @roles, $self->gather_default_action_roles(%args);

       $class = $self->_apply_action_class_roles($class, @roles) if @roles;
    }

    my $action_args = (
        ref($self)
            ? $self->action_args
            : $self->config->{action_args}
    );

    my %extra_args = (
        %{ $action_args->{'*'}           || {} },
        %{ $action_args->{ $args{name} } || {} },
    );

    return $class->new({ %extra_args, %args });
}

sub gather_action_roles {
   my ($self, %args) = @_;
   return (
      (blessed $self ? $self->_action_roles : ()),
      @{ $args{attributes}->{Does} || [] },
   );
}

sub gather_default_action_roles {
  my ($self, %args) = @_;
  my @roles = ();
  push @roles, 'Catalyst::ActionRole::HTTPMethods'
    if $args{attributes}->{Method};

  push @roles, 'Catalyst::ActionRole::ConsumesContent'
    if $args{attributes}->{Consumes};

  push @roles, 'Catalyst::ActionRole::Scheme'
    if $args{attributes}->{Scheme};

  push @roles, 'Catalyst::ActionRole::QueryMatching'
    if $args{attributes}->{Query};
    return @roles;
}

sub _parse_attrs {
    my ( $self, $c, $name, @attrs ) = @_;

    my %raw_attributes;

    foreach my $attr (@attrs) {

        # Parse out :Foo(bar) into Foo => bar etc (and arrayify)

        if ( my ( $key, $value ) = ( $attr =~ /^(.*?)(?:\(\s*(.+?)?\s*\))?$/ ) )
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

    while (my ($key, $value) = each %raw_attributes){
        my $new_attrs = $self->_parse_attr($c, $name, $key => $value );
        push @{ $final_attributes{$_} }, @{ $new_attrs->{$_} } for keys %$new_attrs;
    }

    return \%final_attributes;
}

sub _parse_attr {
    my ($self, $c, $name, $key, $values) = @_;

    my %final_attributes;
    foreach my $value (ref($values) eq 'ARRAY' ? @$values : $values) {
        my $meth = "_parse_${key}_attr";
        if ( my $code = $self->can($meth) ) {
            my %new_attrs = $self->$code( $c, $name, $value );
            while (my ($new_key, $value) = each %new_attrs){
                my $new_attrs = $key eq $new_key ?
                    { $new_key => [$value] } :
                    $self->_parse_attr($c, $name, $new_key => $value );
                push @{ $final_attributes{$_} }, @{ $new_attrs->{$_} } for keys %$new_attrs;
            }
        }
        else {
            push( @{ $final_attributes{$key} }, $value );
        }
    }

    return \%final_attributes;
}

sub _parse_Global_attr {
    my ( $self, $c, $name, $value ) = @_;
    # _parse_attr will call _parse_Path_attr for us
    return Path => "/$name";
}

sub _parse_Absolute_attr { shift->_parse_Global_attr(@_); }

sub _parse_Local_attr {
    my ( $self, $c, $name, $value ) = @_;
    # _parse_attr will call _parse_Path_attr for us
    return Path => $name;
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
    $value = "+${appclass}::Action::${value}";

    return ( 'ActionClass', $value );
}

sub _parse_Does_attr {
    my ($self, $app, $name, $value) = @_;
    return Does => $self->_expand_role_shortname($value);
}

sub _parse_GET_attr     { Method => 'GET'     }
sub _parse_POST_attr    { Method => 'POST'    }
sub _parse_PUT_attr     { Method => 'PUT'     }
sub _parse_DELETE_attr  { Method => 'DELETE'  }
sub _parse_OPTIONS_attr { Method => 'OPTIONS' }
sub _parse_HEAD_attr    { Method => 'HEAD'    }
sub _parse_PATCH_attr  { Method => 'PATCH'  }

sub _expand_role_shortname {
    my ($self, @shortnames) = @_;
    my $app = $self->_application;

    my $prefix = $self->can('_action_role_prefix') ? $self->_action_role_prefix : ['Catalyst::ActionRole::'];
    my @prefixes = (qq{${app}::ActionRole::}, @$prefix);

    return String::RewritePrefix->rewrite(
        { ''  => sub {
            my $loaded = load_first_existing_class(
                map { "$_$_[0]" } @prefixes
            );
            return first { $loaded =~ /^$_/ }
              sort { length $b <=> length $a } @prefixes;
          },
          '~' => $prefixes[0],
          '+' => '' },
        @shortnames,
    );
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

=head2 $self->action_for($action_name)

Returns the Catalyst::Action object (if any) for a given action in this
controller or relative to it.  You may refer to actions in controllers
nested under the current controllers namespace, or in controllers 'up'
from the current controller namespace.  For example:

    package MyApp::Controller::One::Two;
    use base 'Catalyst::Controller';

    sub foo :Local {
      my ($self, $c) = @_;
      $self->action_for('foo'); # action 'foo' in Controller 'One::Two'
      $self->action_for('three/bar'); # action 'bar' in Controller 'One::Two::Three'
      $self->action_for('../boo'); # action 'boo' in Controller 'One'
    }

This returns 'undef' if there is no action matching the requested action
name (after any path normalization) so you should check for this as needed.

=head2 $self->action_namespace($c)

Returns the private namespace for actions in this component. Defaults
to a value from the controller name (for
e.g. MyApp::Controller::Foo::Bar becomes "foo/bar") or can be
overridden from the "namespace" config key.


=head2 $self->path_prefix($c)

Returns the default path prefix for :PathPrefix, :Local and
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

=head2 $self->gather_action_roles(\%action_args)

Gathers the list of roles to apply to an action with the given %action_args.

=head2 $self->gather_default_action_roles(\%action_args)

returns a list of action roles to be applied based on core, builtin rules.
Currently only the L<Catalyst::ActionRole::HTTPMethods> role is applied
this way.

=head2 $self->_application

=head2 $self->_app

Returns the application instance stored by C<new()>

=head1 ACTION SUBROUTINE ATTRIBUTES

Please see L<Catalyst::Manual::Intro> for more details

Think of action attributes as a sort of way to record metadata about an action,
similar to how annotations work in other languages you might have heard of.
Generally L<Catalyst> uses these to influence how the dispatcher sees your
action and when it will run it in response to an incoming request.  They can
also be used for other things.  Here's a summary, but you should refer to the
linked manual page for additional help.

=head2 Global

  sub homepage :Global { ... }

A global action defined in any controller always runs relative to your root.
So the above is the same as:

  sub myaction :Path("/homepage") { ... }

=head2 Absolute

Status: Deprecated alias to L</Global>.

=head2 Local

Alias to "Path("$action_name").  The following two actions are the same:

  sub myaction :Local { ... }
  sub myaction :Path('myaction') { ... }

=head2 Relative

Status: Deprecated alias to L</Local>

=head2 Path

Handle various types of paths:

  package MyApp::Controller::Baz {

    ...

    sub myaction1 :Path { ... }  # -> /baz
    sub myaction2 :Path('foo') { ... } # -> /baz/foo
    sub myaction2 :Path('/bar') { ... } # -> /bar
  }

This is a general toolbox for attaching your action to a given path.


=head2 Regex

=head2 Regexp

B<Status: Deprecated.>  Use Chained methods or other techniques.
If you really depend on this, install the standalone 
L<Catalyst::DispatchType::Regex> distribution.

A global way to match a give regular expression in the incoming request path.

=head2 LocalRegex

=head2 LocalRegexp

B<Status: Deprecated.>  Use Chained methods or other techniques.
If you really depend on this, install the standalone 
L<Catalyst::DispatchType::Regex> distribution.

Like L</Regex> but scoped under the namespace of the containing controller

=head2 Chained 

=head2 ChainedParent

=head2 PathPrefix

=head2 PathPart

=head2 CaptureArgs

Allowed values for CaptureArgs is a single integer (CaptureArgs(2), meaning two
allowed) or you can declare a L<Moose>, L<MooseX::Types> or L<Type::Tiny>
named constraint such as CaptureArgs(Int,Str) would require two args with
the first being a Integer and the second a string.  You may declare your own
custom type constraints and import them into the controller namespace:

    package MyApp::Controller::Root;

    use Moose;
    use MooseX::MethodAttributes;
    use MyApp::Types qw/Int/;

    extends 'Catalyst::Controller';

    sub chain_base :Chained(/) CaptureArgs(1) { }

      sub any_priority_chain :Chained(chain_base) PathPart('') Args(1) { }

      sub int_priority_chain :Chained(chain_base) PathPart('') Args(Int) { }

See L<Catalyst::RouteMatching> for more.

Please see L<Catalyst::DispatchType::Chained> for more.

=head2 ActionClass

Set the base class for the action, defaults to L</Catalyst::Action>.  It is now
preferred to use L</Does>.

=head2 MyAction

Set the ActionClass using a custom Action in your project namespace.

The following is exactly the same:

    sub foo_action1 : Local ActionClass('+MyApp::Action::Bar') { ... }
    sub foo_action2 : Local MyAction('Bar') { ... }

=head2 Does

    package MyApp::Controller::Zoo;

    sub foo  : Local Does('Buzz')  { ... } # Catalyst::ActionRole::
    sub bar  : Local Does('~Buzz') { ... } # MyApp::ActionRole::Buzz
    sub baz  : Local Does('+MyApp::ActionRole::Buzz') { ... }

=head2 GET

=head2 POST

=head2 PUT

=head2 DELETE

=head2 OPTION

=head2 HEAD

=head2 PATCH

=head2 Method('...')

Sets the give action path to match the specified HTTP method, or via one of the
broadly accepted methods of overriding the 'true' method (see
L<Catalyst::ActionRole::HTTPMethods>).

=head2 Args

When used with L</Path> indicates the number of arguments expected in
the path.  However if no Args value is set, assumed to 'slurp' all
remaining path pars under this namespace.

Allowed values for Args is a single integer (Args(2), meaning two allowed) or you
can declare a L<Moose>, L<MooseX::Types> or L<Type::Tiny> named constraint such
as Args(Int,Str) would require two args with the first being a Integer and the
second a string.  You may declare your own custom type constraints and import
them into the controller namespace:

    package MyApp::Controller::Root;

    use Moose;
    use MooseX::MethodAttributes;
    use MyApp::Types qw/Tuple Int Str StrMatch UserId/;

    extends 'Catalyst::Controller';

    sub user :Local Args(UserId) {
      my ($self, $c, $int) = @_;
    }

    sub an_int :Local Args(Int) {
      my ($self, $c, $int) = @_;
    }

    sub many_ints :Local Args(ArrayRef[Int]) {
      my ($self, $c, @ints) = @_;
    }

    sub match :Local Args(StrMatch[qr{\d\d-\d\d-\d\d}]) {
      my ($self, $c, $int) = @_;
    }

If you choose not to use imported type constraints (like L<Type::Tiny>, or <MooseX::Types>
you may use L<Moose> 'stringy' types however just like when you use these types in your
declared attributes you must quote them:

    sub my_moose_type :Local Args('Int') { ... }

If you use 'reference' type constraints (such as ArrayRef[Int]) that have an unknown
number of allowed matches, we set this the same way "Args" is.  Please keep in mind
that actions with an undetermined number of args match at lower precedence than those
with a fixed number.  You may use reference types such as Tuple from L<Types::Standard>
that allows you to fix the number of allowed args.  For example Args(Tuple[Int,Int])
would be determined to be two args (or really the same as Args(Int,Int).)  You may
find this useful for creating custom subtypes with complex matching rules that you 
wish to reuse over many actions.

See L<Catalyst::RouteMatching> for more.

B<Note>: It is highly recommended to use L<Type::Tiny> for your type constraints over
other options.  L<Type::Tiny> exposed a better meta data interface which allows us to
do more and better types of introspection driving tests and debugging.

=head2 Consumes('...')

Matches the current action against the content-type of the request.  Typically
this is used when the request is a POST or PUT and you want to restrict the
submitted content type.  For example, you might have an HTML for that either
returns classic url encoded form data, or JSON when Javascript is enabled.  In
this case you may wish to match either incoming type to one of two different
actions, for properly processing.

Examples:

    sub is_json       : Chained('start') Consumes('application/json') { ... }
    sub is_urlencoded : Chained('start') Consumes('application/x-www-form-urlencoded') { ... }
    sub is_multipart  : Chained('start') Consumes('multipart/form-data') { ... }

To reduce boilerplate, we include the following content type shortcuts:

Examples

      sub is_json       : Chained('start') Consume(JSON) { ... }
      sub is_urlencoded : Chained('start') Consumes(UrlEncoded) { ... }
      sub is_multipart  : Chained('start') Consumes(Multipart) { ... }

You may specify more than one match:

      sub is_more_than_one
        : Chained('start')
        : Consumes('application/x-www-form-urlencoded')
        : Consumes('multipart/form-data')

      sub is_more_than_one
        : Chained('start')
        : Consumes(UrlEncoded)
        : Consumes(Multipart)

Since it is a common case the shortcut C<HTMLForm> matches both
'application/x-www-form-urlencoded' and 'multipart/form-data'.  Here's the full
list of available shortcuts:

    JSON => 'application/json',
    JS => 'application/javascript',
    PERL => 'application/perl',
    HTML => 'text/html',
    XML => 'text/XML',
    Plain => 'text/plain',
    UrlEncoded => 'application/x-www-form-urlencoded',
    Multipart => 'multipart/form-data',
    HTMLForm => ['application/x-www-form-urlencoded','multipart/form-data'],

Please keep in mind that when dispatching, L<Catalyst> will match the first most
relevant case, so if you use the C<Consumes> attribute, you should place your
most accurate matches early in the Chain, and your 'catchall' actions last.

See L<Catalyst::ActionRole::ConsumesContent> for more.

=head2 Scheme(...)

Allows you to specify a URI scheme for the action or action chain.  For example
you can required that a given path be C<https> or that it is a websocket endpoint
C<ws> or C<wss>.  For an action chain you may currently only have one defined
Scheme.

    package MyApp::Controller::Root;

    use base 'Catalyst::Controller';

    sub is_http :Path(scheme) Scheme(http) Args(0) {
      my ($self, $c) = @_;
      $c->response->body("is_http");
    }

    sub is_https :Path(scheme) Scheme(https) Args(0)  {
      my ($self, $c) = @_;
      $c->response->body("is_https");
    }

In the above example http://localhost/root/scheme would match the first
action (is_http) but https://localhost/root/scheme would match the second.

As an added benefit, if an action or action chain defines a Scheme, when using
$c->uri_for the scheme of the generated URL will use what you define in the action
or action chain (the current behavior is to set the scheme based on the current
incoming request).  This makes it easier to use uri_for on websites where some
paths are secure and others are not.  You may also use this to other schemes
like websockets.

See L<Catalyst::ActionRole::Scheme> for more.

=head1 OPTIONAL METHODS

=head2 _parse_[$name]_attr

Allows you to customize parsing of subroutine attributes.

    sub myaction1 :Path TwoArgs { ... }

    sub _parse_TwoArgs_attr {
      my ( $self, $c, $name, $value ) = @_;
      # $self -> controller instance
      #
      return(Args => 2);
    }

Please note that this feature does not let you actually assign new functions
to actions via subroutine attributes, but is really more for creating useful
aliases to existing core and extended attributes, and transforms based on 
existing information (like from configuration).  Code for actually doing
something meaningful with the subroutine attributes will be located in the
L<Catalyst::Action> classes (or your subclasses), L<Catalyst::Dispatcher> and
in subclasses of L<Catalyst::DispatchType>.  Remember these methods only get
called basically once when the application is starting, not per request!

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
