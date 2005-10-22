package Catalyst::Dispatcher;

use strict;
use base 'Class::Accessor::Fast';
use Catalyst::Exception;
use Catalyst::Utils;
use Catalyst::Action;
use Catalyst::ActionContainer;
use Catalyst::DispatchType::Path;
use Catalyst::DispatchType::Regex;
use Catalyst::DispatchType::Default;
use Text::ASCIITable;
use Tree::Simple;
use Tree::Simple::Visitor::FindByPath;

# Stringify to class
use overload '""' => sub { return ref shift }, fallback => 1;

__PACKAGE__->mk_accessors(qw/actions tree dispatch_types/);

=head1 NAME

Catalyst::Dispatcher - The Catalyst Dispatcher

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item $self->detach( $c, $command [, \@arguments ] )

=cut

sub detach {
    my ( $self, $c, $command, @args ) = @_;
    $c->forward( $command, @args ) if $command;
    die $Catalyst::DETACH;
}

=item $self->dispatch($c)

=cut

sub dispatch {
    my ( $self, $c ) = @_;

    if ( $c->action ) {

        my @containers = $self->get_containers( $c->namespace );
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

    else {
        my $path  = $c->req->path;
        my $error = $path
          ? qq/Unknown resource "$path"/
          : "No default action defined";
        $c->log->error($error) if $c->debug;
        $c->error($error);
    }
}

=item $self->forward( $c, $command [, \@arguments ] )

=cut

sub forward {
    my $self    = shift;
    my $c       = shift;
    my $command = shift;

    unless ($command) {
        $c->log->debug('Nothing to forward to') if $c->debug;
        return 0;
    }

    # Relative forwards from detach
    my $caller = ( caller(1) )[0]->isa('Catalyst::Dispatcher')
      && ( ( caller(2) )[3] =~ /::detach$/ ) ? caller(3) : caller(1);

    my $arguments = ( ref( $_[-1] ) eq 'ARRAY' ) ? pop(@_) : $c->req->args;

    my $results = [];

    my $command_copy = $command;

    unless ( $command_copy =~ s/^\/// ) {
        my $namespace =
          Catalyst::Utils::class2prefix( $caller, $c->config->{case_sensitive} )
          || '';
        $command_copy = "${namespace}/${command}";
    }

    unless ( $command_copy =~ /\// ) {
        $results = $c->get_action( $command_copy, '/' );
    }
    else {
        my @extra_args;
      DESCEND: while ( $command_copy =~ s/^(.*)\/(\w+)$/$1/ ) {
            my $tail = $2;
            $results = $c->get_action( $tail, $1 );
            if ( @{$results} ) {
                $command = $tail;
                push( @{$arguments}, @extra_args );
                last DESCEND;
            }
            unshift( @extra_args, $tail );
        }
    }

    unless ( @{$results} ) {

        unless ( $c->components->{$command} ) {
            my $error =
qq/Couldn't forward to command "$command". Invalid action or component./;
            $c->error($error);
            $c->log->debug($error) if $c->debug;
            return 0;
        }

        my $class  = $command;
        my $method = shift || 'process';

        if ( my $code = $c->components->{$class}->can($method) ) {
            my $action = Catalyst::Action->new(
                {
                    name      => $method,
                    code      => $code,
                    reverse   => "$class->$method",
                    namespace => $class,
                    prefix    => $class,
                }
            );
            $results = [ [$action] ];
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

    local $c->request->{arguments} = [ @{$arguments} ];

    for my $result ( @{$results} ) {
        $result->[0]->execute($c);
        return if scalar @{ $c->error };
        last unless $c->state;
    }

    return $c->state;
}

=item $self->prepare_action($c)

=cut

sub prepare_action {
    my ( $self, $c ) = @_;
    my $path = $c->req->path;
    my @path = split /\//, $c->req->path;
    $c->req->args( \my @args );

    push( @path, '/' ) unless @path;    # Root action

  DESCEND: while (@path) {
        $path = join '/', @path;

        $path = '' if $path eq '/';     # Root action

        # Check out dispatch types to see if any will handle the path at
        # this level

        foreach my $type ( @{ $self->dispatch_types } ) {
            last DESCEND if $type->match( $c, $path );
        }

        # If not, move the last part path to args

        unshift @args, pop @path;
    }

    $c->log->debug( 'Arguments are "' . join( '/', @args ) . '"' )
      if ( $c->debug && @args );
}

=item $self->get_action( $c, $action, $namespace, $inherit )

=cut

sub get_action {
    my ( $self, $c, $action, $namespace, $inherit ) = @_;
    return [] unless $action;
    $namespace ||= '/';
    $inherit   ||= 0;

    my @match = $self->get_containers($namespace);

    my @results;

    foreach my $child ( $inherit ? @match : $match[-1] ) {
        my $node = $child->actions;
        push( @results, [ $node->{$action} ] ) if defined $node->{$action};
    }
    return \@results;
}

=item $self->get_containers( $namespace )

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

        my $extra = $path[ ( scalar @match ) - 1 ];
        last unless $extra;
        $visitor->setSearchPath($extra);
        $match[-1]->accept($visitor);
        push( @match, $visitor->getResult ) if defined $visitor->getResult;
    }

    return map { $_->getNodeValue } @match;
}

=item $self->set_action( $c, $action, $code, $namespace, $attrs )

=cut

sub set_action {
    my ( $self, $c, $method, $code, $namespace, $attrs ) = @_;

    my $prefix =
      Catalyst::Utils::class2prefix( $namespace, $c->config->{case_sensitive} )
      || '';
    my %attributes;

    for my $attr ( @{$attrs} ) {

        # Parse out :Foo(bar) into Foo => bar etc (and arrayify)

        if ( my ( $key, $value ) = ( $attr =~ /^(.*?)(?:\(\s*(.+)\s*\))?$/ ) ) {
            if ( defined $value ) {
                ( $value =~ s/^'(.*)'$/$1/ ) || ( $value =~ s/^"(.*)"/$1/ );
            }
            push( @{ $attributes{$key} }, $value );
        }
    }

    if ( $attributes{Private} && ( keys %attributes > 1 ) ) {
        $c->log->debug( 'Bad action definition "'
              . join( ' ', @{$attrs} )
              . qq/" for "$namespace->$method"/ )
          if $c->debug;
        return;
    }
    return unless keys %attributes;

    my $parent  = $self->tree;
    my $visitor = Tree::Simple::Visitor::FindByPath->new;

    if ($prefix) {
        for my $part ( split '/', $prefix ) {
            $visitor->setSearchPath($part);
            $parent->accept($visitor);
            my $child = $visitor->getResult;

            unless ($child) {

                # Create a new tree node and an ActionContainer to form
                # its value.

                my $container =
                  Catalyst::ActionContainer->new(
                    { part => $part, actions => {} } );
                $child = $parent->addChild( Tree::Simple->new($container) );
                $visitor->setSearchPath($part);
                $parent->accept($visitor);
                $child = $visitor->getResult;
            }

            $parent = $child;
        }
    }

    my $reverse = $prefix ? "$prefix/$method" : $method;

    my $action = Catalyst::Action->new(
        {
            name       => $method,
            code       => $code,
            reverse    => $reverse,
            namespace  => $namespace,
            prefix     => $prefix,
            attributes => \%attributes,
        }
    );

    # Set the method value
    $parent->getNodeValue->actions->{$method} = $action;

    # Pass the action to our dispatch types so they can register it if reqd.
    foreach my $type ( @{ $self->dispatch_types } ) {
        $type->register( $c, $action );
    }
}

=item $self->setup_actions( $class, $component )

=cut

sub setup_actions {
    my ( $self, $class ) = @_;

    # These are the core structures
    $self->actions(
        {
            plain    => {},
            private  => {},
            regex    => {},
            compiled => []
        }
    );

    $self->dispatch_types(
        [ map { "Catalyst::DispatchType::$_"->new } qw/Path Regex Default/ ] );

    # We use a tree
    my $container =
      Catalyst::ActionContainer->new( { part => '/', actions => {} } );
    $self->tree( Tree::Simple->new( $container, Tree::Simple->ROOT ) );

    for my $comp ( keys %{ $class->components } ) {

        # We only setup components that inherit from Catalyst::Base
        next unless $comp->isa('Catalyst::Base');

        for my $action ( @{ Catalyst::Utils::reflect_actions($comp) } ) {
            my ( $code, $attrs ) = @{$action};
            my $name = '';
            no strict 'refs';
            my @cache = ( $comp, @{"$comp\::ISA"} );
            my %namespaces;

            while ( my $namespace = shift @cache ) {
                $namespaces{$namespace}++;
                for my $isa ( @{"$comp\::ISA"} ) {
                    next if $namespaces{$isa};
                    push @cache, $isa;
                    $namespaces{$isa}++;
                }
            }

            for my $namespace ( keys %namespaces ) {

                for my $sym ( values %{ $namespace . '::' } ) {

                    if ( *{$sym}{CODE} && *{$sym}{CODE} == $code ) {

                        $name = *{$sym}{NAME};
                        $class->set_action( $name, $code, $comp, $attrs );
                        last;
                    }

                }

            }

        }

    }

    return unless $class->debug;

    my $actions  = $self->actions;
    my $privates = Text::ASCIITable->new;
    $privates->setCols( 'Private', 'Class' );
    $privates->setColWidth( 'Private', 36, 1 );
    $privates->setColWidth( 'Class',   37, 1 );

    my $walker = sub {
        my ( $walker, $parent, $prefix ) = @_;
        $prefix .= $parent->getNodeValue || '';
        $prefix .= '/' unless $prefix =~ /\/$/;
        my $node = $parent->getNodeValue->actions;

        for my $action ( keys %{$node} ) {
            my $action_obj = $node->{$action};
            $privates->addRow( "$prefix$action", $action_obj->namespace );
        }

        $walker->( $walker, $_, $prefix ) for $parent->getAllChildren;
    };

    $walker->( $walker, $self->tree, '' );
    $class->log->debug( "Loaded private actions:\n" . $privates->draw )
      if ( @{ $privates->{tbl_rows} } );

    my $publics = Text::ASCIITable->new;
    $publics->setCols( 'Public', 'Private' );
    $publics->setColWidth( 'Public',  36, 1 );
    $publics->setColWidth( 'Private', 37, 1 );

    for my $plain ( sort keys %{ $actions->{plain} } ) {
        my $action = $actions->{plain}->{$plain};
        $publics->addRow( "/$plain", "/$action" );
    }

    $class->log->debug( "Loaded public actions:\n" . $publics->draw )
      if ( @{ $publics->{tbl_rows} } );

    my $regexes = Text::ASCIITable->new;
    $regexes->setCols( 'Regex', 'Private' );
    $regexes->setColWidth( 'Regex',   36, 1 );
    $regexes->setColWidth( 'Private', 37, 1 );

    for my $regex ( sort keys %{ $actions->{regex} } ) {
        my $action = $actions->{regex}->{$regex};
        $regexes->addRow( $regex, "/$action" );
    }

    $class->log->debug( "Loaded regex actions:\n" . $regexes->draw )
      if ( @{ $regexes->{tbl_rows} } );
}

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
