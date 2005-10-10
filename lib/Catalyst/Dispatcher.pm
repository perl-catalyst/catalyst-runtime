package Catalyst::Dispatcher;

use strict;
use base 'Class::Accessor::Fast';
use Catalyst::Exception;
use Catalyst::Utils;
use Catalyst::Action;
use Text::ASCIITable;
use Tree::Simple;
use Tree::Simple::Visitor::FindByPath;

# Stringify to class
use overload '""' => sub { return ref shift }, fallback => 1;

__PACKAGE__->mk_accessors(qw/actions tree/);

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
    my $action    = $c->req->action;
    my $namespace = '';
    $namespace = ( join( '/', @{ $c->req->args } ) || '/' )
      if $action eq 'default';

    unless ($namespace) {
        if ( my $result = $c->get_action($action) ) {
            $namespace =
              Catalyst::Utils::class2prefix( $result->[0]->[0]->namespace,
                $c->config->{case_sensitive} );
        }
    }

    my $default = $action eq 'default' ? $namespace : undef;
    my $results = $c->get_action( $action, $default, $default ? 1 : 0 );
    $namespace ||= '/';

    if ( @{$results} ) {

        # Errors break the normal flow and the end action is instantly run
        my $error = 0;

        # Execute last begin
        $c->state(1);
        if ( my $begin = @{ $c->get_action( 'begin', $namespace, 1 ) }[-1] ) {
            $begin->[0]->execute($c);
            $error++ if scalar @{ $c->error };
        }

        # Execute the auto chain
        my $autorun = 0;
        for my $auto ( @{ $c->get_action( 'auto', $namespace, 1 ) } ) {
            last if $error;
            $autorun++;
            $auto->[0]->execute($c);
            $error++ if scalar @{ $c->error };
            last unless $c->state;
        }

        # Execute the action or last default
        my $mkay = $autorun ? $c->state ? 1 : 0 : 1;
        if ( ( my $action = $c->req->action ) && $mkay ) {
            unless ($error) {
                if ( my $result =
                    @{ $c->get_action( $action, $default, 1 ) }[-1] )
                {
                    $result->[0]->execute($c);
                    $error++ if scalar @{ $c->error };
                }
            }
        }

        # Execute last end
        if ( my $end = @{ $c->get_action( 'end', $namespace, 1 ) }[-1] ) {
            $end->[0]->execute($c);
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

    my $namespace = '/';
    my $arguments = ( ref( $_[-1] ) eq 'ARRAY' ) ? pop(@_) : $c->req->args;

    my $results = [];

    if ( $command =~ /^\// ) {
        if ( $command =~ /^\/(\w+)$/ ) {
            $results = $c->get_action( $1, $namespace );
        }
        else {
            my $command_copy = $command;
            my @extra_args;
          DESCEND: while ( $command_copy =~ s/^\/(.*)\/(\w+)$/\/$1/ ) {
                my $tail = $2;
                if ( $results = $c->get_action( $tail, $1 ) ) {
                    $command   = $tail;
                    $namespace = $command_copy;
                    push( @{$arguments}, @extra_args );
                    last DESCEND;
                }
                unshift( @extra_args, $tail );
            }
        }
        $command =~ s/^\///;
    }

    else {
        $namespace =
          Catalyst::Utils::class2prefix( $caller, $c->config->{case_sensitive} )
          || '/';
        $results = $c->get_action( $command, $namespace );
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
                    code      => $code,
                    reverse   => "$class->$method",
                    namespace => $class,
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

    while (@path) {
        $path = join '/', @path;
        if ( my $result = ${ $c->get_action($path) }[0] ) {

            # It's a regex
            if ($#$result) {
                my $match    = $result->[1];
                my @snippets = @{ $result->[2] };
                $c->log->debug(
                    qq/Requested action is "$path" and matched "$match"/)
                  if $c->debug;
                $c->log->debug(
                    'Snippets are "' . join( ' ', @snippets ) . '"' )
                  if ( $c->debug && @snippets );
                $c->req->action($match);
                $c->req->snippets( \@snippets );
            }

            else {
                $c->req->action($path);
                $c->log->debug(qq/Requested action is "$path"/) if $c->debug;
            }

            $c->req->match($path);
            last;
        }
        unshift @args, pop @path;
    }

    unless ( $c->req->action ) {
        $c->req->action('default');
        $c->req->match('');
    }

    $c->log->debug( 'Arguments are "' . join( '/', @args ) . '"' )
      if ( $c->debug && @args );
}

=item $self->get_action( $c, $action, $namespace, $inherit )

=cut

sub get_action {
    my ( $self, $c, $action, $namespace, $inherit ) = @_;
    return [] unless $action;
    $namespace ||= '';
    $inherit   ||= 0;

    if ($namespace) {
        $namespace = '' if $namespace eq '/';
        my $parent = $self->tree;
        my @results;

        if ($inherit) {
            my $result =
              $self->actions->{private}->{ $parent->getUID }->{$action};
            push @results, [$result] if $result;
            my $visitor = Tree::Simple::Visitor::FindByPath->new;

          SEARCH:
            for my $part ( split '/', $namespace ) {
                $visitor->setSearchPath($part);
                $parent->accept($visitor);
                my $child = $visitor->getResult;
                my $uid   = $child->getUID if $child;
                my $match = $self->actions->{private}->{$uid}->{$action}
                  if $uid;
                push @results, [$match] if $match;
                if ($child) {
                    $parent = $child;
                }
                else {
                    last SEARCH;
                }
            }

        }

        else {

            if ($namespace) {
                my $visitor = Tree::Simple::Visitor::FindByPath->new;
                $visitor->setSearchPath( split '/', $namespace );
                $parent->accept($visitor);
                my $child = $visitor->getResult;
                my $uid   = $child->getUID if $child;
                my $match = $self->actions->{private}->{$uid}->{$action}
                  if $uid;
                push @results, [$match] if $match;
            }

            else {
                my $result =
                  $self->actions->{private}->{ $parent->getUID }->{$action};
                push @results, [$result] if $result;
            }

        }
        return \@results;
    }

    elsif ( my $p = $self->actions->{plain}->{$action} ) { return [ [$p] ] }
    elsif ( my $r = $self->actions->{regex}->{$action} ) { return [ [$r] ] }

    else {

        for my $i ( 0 .. $#{ $self->actions->{compiled} } ) {
            my $name  = $self->actions->{compiled}->[$i]->[0];
            my $regex = $self->actions->{compiled}->[$i]->[1];

            if ( my @snippets = ( $action =~ $regex ) ) {
                return [
                    [ $self->actions->{regex}->{$name}, $name, \@snippets ] ];
            }

        }
    }
    return [];
}

=item $self->set_action( $c, $action, $code, $namespace, $attrs )

=cut

sub set_action {
    my ( $self, $c, $method, $code, $namespace, $attrs ) = @_;

    my $prefix =
      Catalyst::Utils::class2prefix( $namespace, $c->config->{case_sensitive} )
      || '';
    my %flags;

    for my $attr ( @{$attrs} ) {
        if    ( $attr =~ /^(Local|Relative)$/ )    { $flags{local}++ }
        elsif ( $attr =~ /^(Global|Absolute)$/ )   { $flags{global}++ }
        elsif ( $attr =~ /^Path\(\s*(.+)\s*\)$/i ) { $flags{path} = $1 }
        elsif ( $attr =~ /^Private$/i )            { $flags{private}++ }
        elsif ( $attr =~ /^(Regex|Regexp)\(\s*(.+)\s*\)$/i ) {
            $flags{regex} = $2;
        }
    }

    if ( $flags{private} && ( keys %flags > 1 ) ) {
        $c->log->debug( 'Bad action definition "'
              . join( ' ', @{$attrs} )
              . qq/" for "$namespace->$method"/ )
          if $c->debug;
        return;
    }
    return unless keys %flags;

    my $parent  = $self->tree;
    my $visitor = Tree::Simple::Visitor::FindByPath->new;

    for my $part ( split '/', $prefix ) {
        $visitor->setSearchPath($part);
        $parent->accept($visitor);
        my $child = $visitor->getResult;

        unless ($child) {
            $child = $parent->addChild( Tree::Simple->new($part) );
            $visitor->setSearchPath($part);
            $parent->accept($visitor);
            $child = $visitor->getResult;
        }

        $parent = $child;
    }

    my $forward = $prefix ? "$prefix/$method" : $method;

    my $reverse = $prefix ? "$prefix/$method" : $method;

    my $action = Catalyst::Action->new(
        {
            code      => $code,
            reverse   => $reverse,
            namespace => $namespace,
        }
    );

    my $uid = $parent->getUID;
    $self->actions->{private}->{$uid}->{$method} = $action;

    if ( $flags{path} ) {
        $flags{path} =~ s/^\w+//;
        $flags{path} =~ s/\w+$//;
        if ( $flags{path} =~ /^\s*'(.*)'\s*$/ ) { $flags{path} = $1 }
        if ( $flags{path} =~ /^\s*"(.*)"\s*$/ ) { $flags{path} = $1 }
    }

    if ( $flags{regex} ) {
        $flags{regex} =~ s/^\w+//;
        $flags{regex} =~ s/\w+$//;
        if ( $flags{regex} =~ /^\s*'(.*)'\s*$/ ) { $flags{regex} = $1 }
        if ( $flags{regex} =~ /^\s*"(.*)"\s*$/ ) { $flags{regex} = $1 }
    }

    if ( $flags{local} || $flags{global} || $flags{path} ) {
        my $path     = $flags{path} || $method;
        my $absolute = 0;

        if ( $path =~ /^\/(.+)/ ) {
            $path     = $1;
            $absolute = 1;
        }

        $absolute = 1 if $flags{global};
        my $name = $absolute ? $path : $prefix ? "$prefix/$path" : $path;
        $self->actions->{plain}->{$name} = $action;
    }

    if ( my $regex = $flags{regex} ) {
        push @{ $self->actions->{compiled} }, [ $regex, qr#$regex# ];
        $self->actions->{regex}->{$regex} = $action;
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

    # We use a tree
    $self->tree( Tree::Simple->new( 0, Tree::Simple->ROOT ) );

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
        my $uid = $parent->getUID;

        for my $action ( keys %{ $actions->{private}->{$uid} } ) {
            my $action_obj = $actions->{private}->{$uid}->{$action};
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
