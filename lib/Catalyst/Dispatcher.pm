package Catalyst::Dispatcher;

use Moose;

use Catalyst::Exception;
use Catalyst::Utils;
use Catalyst::Action;
use Catalyst::ActionContainer;
use Catalyst::DispatchType::Default;
use Catalyst::DispatchType::Index;
use Text::SimpleTable;
use Tree::Simple;
use Tree::Simple::Visitor::FindByPath;
use Scalar::Util ();

# Stringify to class
use overload '""' => sub { return ref shift }, fallback => 1;


# Preload these action types
our @PRELOAD = qw/Index Path Regex/;

# Postload these action types
our @POSTLOAD = qw/Default/;

has _tree                       => (is => 'rw');
has _dispatch_types             => (is => 'rw');
has _registered_dispatch_types  => (is => 'rw');
has _method_action_class        => (is => 'rw');
has _action_container_class     => (is => 'rw');
has preload_dispatch_types      => (is => 'rw', required => 1, lazy => 1, default => sub { [@PRELOAD] });
has postload_dispatch_types     => (is => 'rw', required => 1, lazy => 1, default => sub { [@POSTLOAD] });
has _action_hash                => (is => 'rw', required => 1, lazy => 1, default => sub { {} });
has _container_hash             => (is => 'rw', required => 1, lazy => 1, default => sub { {} });

no Moose;

=head1 NAME

Catalyst::Dispatcher - The Catalyst Dispatcher

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is the class that maps public urls to actions in your Catalyst
application based on the attributes you set.

=head1 METHODS

=head2 new 

Construct a new dispatcher.

=cut

sub BUILD {
  my ($self, $params) = @_;

  my $container = 
    Catalyst::ActionContainer->new( { part => '/', actions => {} } );

  $self->_tree( Tree::Simple->new( $container, Tree::Simple->ROOT ) );
}

=head2 $self->preload_dispatch_types

An arrayref of pre-loaded dispatchtype classes

Entries are considered to be available as C<Catalyst::DispatchType::CLASS>
To use a custom class outside the regular C<Catalyst> namespace, prefix
it with a C<+>, like so:

    +My::Dispatch::Type

=head2 $self->postload_dispatch_types

An arrayref of post-loaded dispatchtype classes

Entries are considered to be available as C<Catalyst::DispatchType::CLASS>
To use a custom class outside the regular C<Catalyst> namespace, prefix
it with a C<+>, like so:

    +My::Dispatch::Type

=head2 $self->detach( $c, $command [, \@arguments ] )

Documented in L<Catalyst>

=cut

sub detach {
    my ( $self, $c, $command, @args ) = @_;
    $c->forward( $command, @args ) if $command;
    die $Catalyst::DETACH;
}

=head2 $self->dispatch($c)

Delegate the dispatch to the action that matched the url, or return a
message about unknown resource


=cut

sub dispatch {
    my ( $self, $c ) = @_;
    if ( $c->action ) {
        $c->forward( join( '/', '', $c->action->namespace, '_DISPATCH' ) );
    }

    else {
        my $path  = $c->req->path;
        my $error = $path
          ? qq/Unknown resource "$path"/
          : "No default action defined";
        $c->log->error($error) if $c->debug;
        $c->error($error);
    }
}

=head2 $self->forward( $c, $command [, \@arguments ] )

Documented in L<Catalyst>

=cut

sub forward {
    my ( $self, $c, $command, @extra_params ) = @_;

    unless ($command) {
        $c->log->debug('Nothing to forward to') if $c->debug;
        return 0;
    }

    my @args;
    
    if ( ref( $extra_params[-1] ) eq 'ARRAY' ) {
        @args = @{ pop @extra_params }
    } else {
        # this is a copy, it may take some abuse from ->_invoke_as_path if the path had trailing parts
        @args = @{ $c->request->arguments };
    }

    my $action;

    # forward to a string path ("/foo/bar/gorch") or action object which stringifies to that
    $action = $self->_invoke_as_path( $c, "$command", \@args );

    # forward to a component ( "MyApp::*::Foo" or $c->component("...") - a path or an object)
    unless ($action) {
        my $method = @extra_params ? $extra_params[0] : "process";
        $action = $self->_invoke_as_component( $c, $command, $method );
    }


    unless ($action) {
        my $error =
            qq/Couldn't forward to command "$command": /
          . qq/Invalid action or component./;
        $c->error($error);
        $c->log->debug($error) if $c->debug;
        return 0;
    }

    #push @$args, @_;

    no warnings 'recursion';

    local $c->request->{arguments} = \@args;
    $action->dispatch( $c );

    return $c->state;
}

sub _action_rel2abs {
    my ( $self, $c, $path ) = @_;

    unless ( $path =~ m#^/# ) {
        my $namespace = $c->stack->[-1]->namespace;
        $path = "$namespace/$path";
    }

    $path =~ s#^/##;
    return $path;
}

sub _invoke_as_path {
    my ( $self, $c, $rel_path, $args ) = @_;

    my $path = $self->_action_rel2abs( $c, $rel_path );

    my ( $tail, @extra_args );
    while ( ( $path, $tail ) = ( $path =~ m#^(?:(.*)/)?(\w+)?$# ) )
    {                           # allow $path to be empty
        if ( my $action = $c->get_action( $tail, $path ) ) {
            push @$args, @extra_args;
            return $action;
        }
        else {
            return
              unless $path
              ; # if a match on the global namespace failed then the whole lookup failed
        }

        unshift @extra_args, $tail;
    }
}

sub _find_component_class {
    my ( $self, $c, $component ) = @_;

    return ref($component)
      || ref( $c->component($component) )
      || $c->component($component);
}

sub _invoke_as_component {
    my ( $self, $c, $component, $method ) = @_;

    my $class = $self->_find_component_class( $c, $component ) || return 0;

    if ( my $code = $class->can($method) ) {
        return $self->_method_action_class->new(
            {
                name      => $method,
                code      => $code,
                reverse   => "$class->$method",
                class     => $class,
                namespace => Catalyst::Utils::class2prefix(
                    $class, $c->config->{case_sensitive}
                ),
            }
        );
    }
    else {
        my $error =
          qq/Couldn't forward to "$class". Does not implement "$method"/;
        $c->error($error);
        $c->log->debug($error)
          if $c->debug;
        return 0;
    }
}

=head2 $self->prepare_action($c)

Find an dispatch type that matches $c->req->path, and set args from it.

=cut

sub prepare_action {
    my ( $self, $c ) = @_;
    my $path = $c->req->path;
    my @path = split /\//, $c->req->path;
    $c->req->args( \my @args );

    unshift( @path, '' );    # Root action

  DESCEND: while (@path) {
        $path = join '/', @path;
        $path =~ s#^/##;

        $path = '' if $path eq '/';    # Root action

        # Check out dispatch types to see if any will handle the path at
        # this level

        foreach my $type ( @{ $self->_dispatch_types } ) {
            last DESCEND if $type->match( $c, $path );
        }

        # If not, move the last part path to args
        my $arg = pop(@path);
        $arg =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
        unshift @args, $arg;
    }

    s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg for grep { defined } @{$c->req->captures||[]};

    $c->log->debug( 'Path is "' . $c->req->match . '"' )
      if ( $c->debug && $c->req->match );

    $c->log->debug( 'Arguments are "' . join( '/', @args ) . '"' )
      if ( $c->debug && @args );
}

=head2 $self->get_action( $action, $namespace )

returns a named action from a given namespace.

=cut

sub get_action {
    my ( $self, $name, $namespace ) = @_;
    return unless $name;

    $namespace = join( "/", grep { length } split '/', $namespace || "" );

    return $self->_action_hash->{"$namespace/$name"};
}

=head2 $self->get_action_by_path( $path ); 
   
Returns the named action by its full path. 

=cut 

sub get_action_by_path {
    my ( $self, $path ) = @_;
    $path =~ s/^\///;
    $path = "/$path" unless $path =~ /\//;
    $self->_action_hash->{$path};
}

=head2 $self->get_actions( $c, $action, $namespace )

=cut

sub get_actions {
    my ( $self, $c, $action, $namespace ) = @_;
    return [] unless $action;

    $namespace = join( "/", grep { length } split '/', $namespace || "" );

    my @match = $self->get_containers($namespace);

    return map { $_->get_action($action) } @match;
}

=head2 $self->get_containers( $namespace )

Return all the action containers for a given namespace, inclusive

=cut

sub get_containers {
    my ( $self, $namespace ) = @_;
    $namespace ||= '';
    $namespace = '' if $namespace eq '/';

    my @containers;

    if ( length $namespace ) {
        do {
            push @containers, $self->_container_hash->{$namespace};
        } while ( $namespace =~ s#/[^/]+$## );
    }

    return reverse grep { defined } @containers, $self->_container_hash->{''};

    my @parts = split '/', $namespace;
}

=head2 $self->uri_for_action($action, \@captures)

Takes a Catalyst::Action object and action parameters and returns a URI
part such that if $c->req->path were this URI part, this action would be
dispatched to with $c->req->captures set to the supplied arrayref.

If the action object is not available for external dispatch or the dispatcher
cannot determine an appropriate URI, this method will return undef.

=cut

sub uri_for_action {
    my ( $self, $action, $captures) = @_;
    $captures ||= [];
    foreach my $dispatch_type ( @{ $self->_dispatch_types } ) {
        my $uri = $dispatch_type->uri_for_action( $action, $captures );
        return( $uri eq '' ? '/' : $uri )
            if defined($uri);
    }
    return undef;
}

=head2 $self->register( $c, $action )

Make sure all required dispatch types for this action are loaded, then
pass the action to our dispatch types so they can register it if required.
Also, set up the tree with the action containers.

=cut

sub register {
    my ( $self, $c, $action ) = @_;

    my $registered = $self->_registered_dispatch_types;

    my $priv = 0;
    foreach my $key ( keys %{ $action->attributes } ) {
        next if $key eq 'Private';
        my $class = "Catalyst::DispatchType::$key";
        unless ( $registered->{$class} ) {
            eval "require $class";
            push( @{ $self->_dispatch_types }, $class->new ) unless $@;
            $registered->{$class} = 1;
        }
    }

    # Pass the action to our dispatch types so they can register it if reqd.
    foreach my $type ( @{ $self->_dispatch_types } ) {
        $type->register( $c, $action );
    }

    my $namespace = $action->namespace;
    my $name      = $action->name;

    my $container = $self->_find_or_create_action_container($namespace);

    # Set the method value
    $container->add_action($action);

    $self->_action_hash->{"$namespace/$name"} = $action;
    $self->_container_hash->{$namespace} = $container;
}

sub _find_or_create_action_container {
    my ( $self, $namespace ) = @_;

    my $tree ||= $self->_tree;

    return $tree->getNodeValue unless $namespace;

    my @namespace = split '/', $namespace;
    return $self->_find_or_create_namespace_node( $tree, @namespace )
      ->getNodeValue;
}

sub _find_or_create_namespace_node {
    my ( $self, $parent, $part, @namespace ) = @_;

    return $parent unless $part;

    my $child =
      ( grep { $_->getNodeValue->part eq $part } $parent->getAllChildren )[0];

    unless ($child) {
        my $container = Catalyst::ActionContainer->new($part);
        $parent->addChild( $child = Tree::Simple->new($container) );
    }

    $self->_find_or_create_namespace_node( $child, @namespace );
}

=head2 $self->setup_actions( $class, $context )


=cut

sub setup_actions {
    my ( $self, $c ) = @_;

    $self->_dispatch_types( [] );
    $self->_registered_dispatch_types( {} );
    $self->_method_action_class('Catalyst::Action');
    $self->_action_container_class('Catalyst::ActionContainer');

    my @classes =
      $self->_load_dispatch_types( @{ $self->preload_dispatch_types } );
    @{ $self->_registered_dispatch_types }{@classes} = (1) x @classes;

    foreach my $comp ( values %{ $c->components } ) {
        $comp->register_actions($c) if $comp->can('register_actions');
    }

    $self->_load_dispatch_types( @{ $self->postload_dispatch_types } );

    return unless $c->debug;

    my $privates = Text::SimpleTable->new(
        [ 20, 'Private' ],
        [ 36, 'Class' ],
        [ 12, 'Method' ]
    );

    my $has_private = 0;
    my $walker = sub {
        my ( $walker, $parent, $prefix ) = @_;
        $prefix .= $parent->getNodeValue || '';
        $prefix .= '/' unless $prefix =~ /\/$/;
        my $node = $parent->getNodeValue->actions;

        for my $action ( keys %{$node} ) {
            my $action_obj = $node->{$action};
            next
              if ( ( $action =~ /^_.*/ )
                && ( !$c->config->{show_internal_actions} ) );
            $privates->row( "$prefix$action", $action_obj->class, $action );
            $has_private = 1;
        }

        $walker->( $walker, $_, $prefix ) for $parent->getAllChildren;
    };

    $walker->( $walker, $self->_tree, '' );
    $c->log->debug( "Loaded Private actions:\n" . $privates->draw . "\n" )
      if $has_private;

    # List all public actions
    $_->list($c) for @{ $self->_dispatch_types };
}

sub _load_dispatch_types {
    my ( $self, @types ) = @_;

    my @loaded;

    # Preload action types
    for my $type (@types) {
        my $class =
          ( $type =~ /^\+(.*)$/ ) ? $1 : "Catalyst::DispatchType::${type}";
        eval "require $class";
        Catalyst::Exception->throw( message => qq/Couldn't load "$class"/ )
          if $@;
        push @{ $self->_dispatch_types }, $class->new;

        push @loaded, $class;
    }

    return @loaded;
}

=head2 meta

Provided by Moose

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Matt S Trout, C<mst@shadowcatsystems.co.uk>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
