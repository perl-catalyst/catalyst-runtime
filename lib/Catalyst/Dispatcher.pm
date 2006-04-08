package Catalyst::Dispatcher;

use strict;
use base 'Class::Accessor::Fast';
use Catalyst::Exception;
use Catalyst::Utils;
use Catalyst::Action;
use Catalyst::ActionContainer;
use Catalyst::DispatchType::Default;
use Catalyst::DispatchType::Index;
use Text::SimpleTable;
use Tree::Simple;
use Tree::Simple::Visitor::FindByPath;

# Stringify to class
use overload '""' => sub { return ref shift }, fallback => 1;

__PACKAGE__->mk_accessors(
    qw/tree dispatch_types registered_dispatch_types
      method_action_class action_container_class
      preload_dispatch_types postload_dispatch_types
      /
);

# Preload these action types
our @PRELOAD = qw/Index Path Regex/;

# Postload these action types
our @POSTLOAD = qw/Default/;

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

sub new {
    my $self  = shift;
    my $class = ref($self) || $self;

    my $obj = $class->SUPER::new(@_);

    # set the default pre- and and postloads
    $obj->preload_dispatch_types( \@PRELOAD );
    $obj->postload_dispatch_types( \@POSTLOAD );
    return $obj;
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
    my $self    = shift;
    my $c       = shift;
    my $command = shift;

    unless ($command) {
        $c->log->debug('Nothing to forward to') if $c->debug;
        return 0;
    }

    my $local_args = 0;
    my $arguments  = $c->req->args;
    if ( ref( $_[-1] ) eq 'ARRAY' ) {
        $arguments  = pop(@_);
        $local_args = 1;
    }

    my $result;

    unless ( ref $command ) {
        my $command_copy = $command;

        unless ( $command_copy =~ s/^\/// ) {
            my $namespace = $c->stack->[-1]->namespace;
            $command_copy = "${namespace}/${command}";
        }

        unless ( $command_copy =~ /\// ) {
            $result = $c->get_action( $command_copy, '/' );
        }
        else {
            my @extra_args;
          DESCEND: while ( $command_copy =~ s/^(.*)\/(\w+)$/$1/ ) {
                my $tail = $2;
                $result = $c->get_action( $tail, $1 );
                if ($result) {
                    $local_args = 1;
                    $command    = $tail;
                    unshift( @{$arguments}, @extra_args );
                    last DESCEND;
                }
                unshift( @extra_args, $tail );
            }
        }
    }

    unless ($result) {

        my $class = ref($command)
          || ref( $c->component($command) )
          || $c->component($command);
        my $method = shift || 'process';

        unless ($class) {
            my $error =
qq/Couldn't forward to command "$command". Invalid action or component./;
            $c->error($error);
            $c->log->debug($error) if $c->debug;
            return 0;
        }

        if ( my $code = $class->can($method) ) {
            my $action = $self->method_action_class->new(
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
            $result = $action;
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

    if ($local_args) {
        local $c->request->{arguments} = [ @{$arguments} ];
        $result->execute($c);
    }
    else { $result->execute($c) }

    return $c->state;
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

        foreach my $type ( @{ $self->dispatch_types } ) {
            last DESCEND if $type->match( $c, $path );
        }

        # If not, move the last part path to args
        my $arg = pop(@path);
        $arg =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
        unshift @args, $arg;
    }

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
    $namespace ||= '';
    $namespace = '' if $namespace eq '/';

    my @match = $self->get_containers($namespace);

    return unless @match;

    if ( my $action = $match[-1]->get_action($name) ) {
        return $action if $action->namespace eq $namespace;
    }
}

=head2 $self->get_actions( $c, $action, $namespace )

=cut

sub get_actions {
    my ( $self, $c, $action, $namespace ) = @_;
    return [] unless $action;
    $namespace ||= '';
    $namespace = '' if $namespace eq '/';

    my @match = $self->get_containers($namespace);

    return map { $_->get_action($action) } @match;
}

=head2 $self->get_containers( $namespace )

Return all the action containers for a given namespace, inclusive

=cut

sub get_containers {
    my ( $self, $namespace ) = @_;

    # If the namespace is / just return the root ActionContainer

    return ( $self->tree->getNodeValue )
      if ( !$namespace || ( $namespace eq '/' ) );

    # Use a visitor to recurse down the tree finding the ActionContainers
    # for each namespace in the chain.

    my $visitor = Tree::Simple::Visitor::FindByPath->new;
    my @path = split( '/', $namespace );
    $visitor->setSearchPath(@path);
    $self->tree->accept($visitor);

    my @match = $visitor->getResults;
    @match = ( $self->tree ) unless @match;

    if ( !defined $visitor->getResult ) {

        # If we don't manage to match, the visitor doesn't return the last
        # node is matched, so foo/bar/baz would only find the 'foo' node,
        # not the foo and foo/bar nodes as it should. This does another
        # single-level search to see if that's the case, and the 'last unless'
        # should catch any failures - or short-circuit this if this *is* a
        # bug in the visitor and gets fixed.

        if ( my $extra = $path[ ( scalar @match ) - 1 ] ) {
            $visitor->setSearchPath($extra);
            $match[-1]->accept($visitor);
            push( @match, $visitor->getResult ) if defined $visitor->getResult;
        }
    }

    return map { $_->getNodeValue } @match;
}

=head2 $self->register( $c, $action )

Make sure all required dispatch types for this action are loaded, then
pass the action to our dispatch types so they can register it if required.
Also, set up the tree with the action containers.

=cut

sub register {
    my ( $self, $c, $action ) = @_;

    my $registered = $self->registered_dispatch_types;

    my $priv = 0;
    foreach my $key ( keys %{ $action->attributes } ) {
        $priv++ if $key eq 'Private';
        my $class = "Catalyst::DispatchType::$key";
        unless ( $registered->{$class} ) {
            eval "require $class";
            push( @{ $self->dispatch_types }, $class->new ) unless $@;
            $registered->{$class} = 1;
        }
    }

    # Pass the action to our dispatch types so they can register it if reqd.
    my $reg = 0;
    foreach my $type ( @{ $self->dispatch_types } ) {
        $reg++ if $type->register( $c, $action );
    }

    return unless $reg + $priv;

    my $namespace = $action->namespace;
	my $node = $self->find_or_create_namespace_node( $namespace );

    # Set the method value
    $node->getNodeValue->actions->{ $action->name } = $action;
}

sub find_or_create_namespace_node {
	my ( $self, $namespace ) = @_;
	
    my $tree  ||= $self->tree;

	return $tree unless $namespace;

	my @namespace = split '/', $namespace;
	return $self->_find_or_create_namespace_node( $tree, @namespace );
}

sub _find_or_create_namespace_node {
	my ( $self, $parent, $part, @namespace ) = @_;

	return $parent unless $part;

	my $child = ( grep { $_->getNodeValue->part eq $part } $parent->getAllChildren )[0];

	unless ($child) {
		# Create a new tree node and an ActionContainer to form
		# its value.

		my $container =
		  Catalyst::ActionContainer->new(
			{ part => $part, actions => {} } );

		$parent->addChild( $child = Tree::Simple->new($container) );
	}

	$self->_find_or_create_namespace_node( $child, @namespace );
}

=head2 $self->setup_actions( $class, $context )


=cut

sub setup_actions {
    my ( $self, $c ) = @_;

    $self->dispatch_types( [] );
    $self->registered_dispatch_types( {} );
    $self->method_action_class('Catalyst::Action');
    $self->action_container_class('Catalyst::ActionContainer');

    my @classes =
      $self->do_load_dispatch_types( @{ $self->preload_dispatch_types } );
    @{ $self->registered_dispatch_types }{@classes} = (1) x @classes;

    # Create the root node of the tree
    my $container =
      Catalyst::ActionContainer->new( { part => '/', actions => {} } );
    $self->tree( Tree::Simple->new( $container, Tree::Simple->ROOT ) );

    foreach my $comp ( values %{ $c->components } ) {
        $comp->register_actions($c) if $comp->can('register_actions');
    }

    $self->do_load_dispatch_types( @{ $self->postload_dispatch_types } );

    return unless $c->debug;

    my $privates = Text::SimpleTable->new(
        [ 20, 'Private' ],
        [ 38, 'Class' ],
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

    $walker->( $walker, $self->tree, '' );
    $c->log->debug( "Loaded Private actions:\n" . $privates->draw )
      if ($has_private);

    # List all public actions
    $_->list($c) for @{ $self->dispatch_types };
}

sub do_load_dispatch_types {
    my ( $self, @types ) = @_;

    my @loaded;

    # Preload action types
    for my $type (@types) {
        my $class =
          ( $type =~ /^\+(.*)$/ ) ? $1 : "Catalyst::DispatchType::${type}";
        eval "require $class";
        Catalyst::Exception->throw( message => qq/Couldn't load "$class"/ )
          if $@;
        push @{ $self->dispatch_types }, $class->new;

        push @loaded, $class;
    }

	return @loaded;
}

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Matt S Trout, C<mst@shadowcatsystems.co.uk>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
