package Catalyst::Dispatcher;

use strict;
use base 'Class::Data::Inheritable';
use Catalyst::Utils;
use Text::ASCIITable;
use Tree::Simple;
use Tree::Simple::Visitor::FindByPath;

__PACKAGE__->mk_classdata($_) for qw/actions tree/;

=head1 NAME

Catalyst::Dispatcher - The Catalyst Dispatcher

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item $c->dispatch

Dispatch request to actions.

=cut

sub dispatch {
    my $c         = shift;
    my $action    = $c->req->action;
    my $namespace = '';
    $namespace = ( join( '/', @{ $c->req->args } ) || '/' )
      if $action eq 'default';

    unless ($namespace) {
        if ( my $result = $c->get_action($action) ) {
            $namespace =
              Catalyst::Utils::class2prefix( $result->[0]->[0]->[0] );
        }
    }

    my $default = $action eq 'default' ? $namespace : undef;
    my $results = $c->get_action( $action, $default, $default ? 1 : 0 );
    $namespace ||= '/';

    if ( @{$results} ) {

        # Execute last begin
        $c->state(1);
        if ( my $begin = @{ $c->get_action( 'begin', $namespace, 1 ) }[-1] ) {
            $c->execute( @{ $begin->[0] } );
            return if scalar @{ $c->error };
        }

        # Execute the auto chain
        my $auto;
        for $auto ( @{ $c->get_action( 'auto', $namespace, 1 ) } ) {
            $c->execute( @{ $auto->[0] } );
            return if scalar @{ $c->error };
            last unless $c->state;
        }

        # Execute the action or last default
        my $mkay = defined $auto ? $c->state ? 1 : 0 : 1;
        if ( ( my $action = $c->req->action ) && $mkay ) {
            if ( my $result = @{ $c->get_action( $action, $default, 1 ) }[-1] )
            {
                $c->execute( @{ $result->[0] } );
            }
        }

        # Execute last end
        if ( my $end = @{ $c->get_action( 'end', $namespace, 1 ) }[-1] ) {
            $c->execute( @{ $end->[0] } );
            return if scalar @{ $c->error };
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

=item $c->forward($command)

Forward processing to a private action or a method from a class.
If you define a class without method it will default to process().

    $c->forward('/foo');
    $c->forward('index');
    $c->forward(qw/MyApp::Model::CDBI::Foo do_stuff/);
    $c->forward('MyApp::View::TT');

=cut

sub forward {
    my $c       = shift;
    my $command = shift;

    unless ($command) {
        $c->log->debug('Nothing to forward to') if $c->debug;
        return 0;
    }

    my $caller    = caller(0);
    my $namespace = '/';

    if ( $command =~ /^\// ) {
        $command =~ /^\/(.*)\/(\w+)$/;
        $namespace = $1 || '/';
        $command   = $2 || $command;
        $command =~ s/^\///;
    }

    else { $namespace = Catalyst::Utils::class2prefix($caller) || '/' }

    my $results = $c->get_action( $command, $namespace );

    unless ( @{$results} ) {
        my $class = $command || '';
        my $path = $class . '.pm';
        $path =~ s/::/\//g;

        unless ( $INC{$path} ) {
            my $error =
              qq/Couldn't forward to "$class". Invalid or not loaded./;
            $c->error($error);
            $c->log->debug($error) if $c->debug;
            return 0;
        }

        unless ( UNIVERSAL::isa( $class, 'Catalyst::Base' ) ) {
            my $error =
              qq/Can't forward to "$class". Class is not a Catalyst component./;
            $c->error($error);
            $c->log->debug($error) if $c->debug;
            return 0;
        }

        my $method = shift || 'process';

        if ( my $code = $class->can($method) ) {
            $c->actions->{reverse}->{"$code"} = "$class->$method";
            $results = [ [ [ $class, $code ] ] ];
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

    for my $result ( @{$results} ) {
        $c->execute( @{ $result->[0] } );
        return if scalar @{ $c->error };
        last unless $c->state;
    }

    return $c->state;
}

=item $c->get_action( $action, $namespace, $inherit )

Get an action in a given namespace.

=cut

sub get_action {
    my ( $c, $action, $namespace, $inherit ) = @_;
    return [] unless $action;
    $namespace ||= '';
    $inherit   ||= 0;

    if ($namespace) {
        $namespace = '' if $namespace eq '/';
        my $parent = $c->tree;
        my @results;

        if ($inherit) {
            my $result = $c->actions->{private}->{ $parent->getUID }->{$action};
            push @results, [$result] if $result;
            my $visitor = Tree::Simple::Visitor::FindByPath->new;

            for my $part ( split '/', $namespace ) {
                $visitor->setSearchPath($part);
                $parent->accept($visitor);
                my $child = $visitor->getResult;
                my $uid   = $child->getUID if $child;
                my $match = $c->actions->{private}->{$uid}->{$action} if $uid;
                push @results, [$match] if $match;
                $parent = $child if $child;
            }

        }

        else {

            if ($namespace) {
                my $visitor = Tree::Simple::Visitor::FindByPath->new;
                $visitor->setSearchPath( split '/', $namespace );
                $parent->accept($visitor);
                my $child = $visitor->getResult;
                my $uid   = $child->getUID if $child;
                my $match = $c->actions->{private}->{$uid}->{$action}
                  if $uid;
                push @results, [$match] if $match;
            }

            else {
                my $result =
                  $c->actions->{private}->{ $parent->getUID }->{$action};
                push @results, [$result] if $result;
            }

        }
        return \@results;
    }

    elsif ( my $p = $c->actions->{plain}->{$action} ) { return [ [$p] ] }
    elsif ( my $r = $c->actions->{regex}->{$action} ) { return [ [$r] ] }

    else {

        for my $i ( 0 .. $#{ $c->actions->{compiled} } ) {
            my $name  = $c->actions->{compiled}->[$i]->[0];
            my $regex = $c->actions->{compiled}->[$i]->[1];

            if ( my @snippets = ( $action =~ $regex ) ) {
                return [ [ $c->actions->{regex}->{$name}, $name, \@snippets ] ];
            }

        }
    }
    return [];
}

=item $c->set_action( $action, $code, $namespace, $attrs )

Set an action in a given namespace.

=cut

sub set_action {
    my ( $c, $method, $code, $namespace, $attrs ) = @_;

    my $prefix = Catalyst::Utils::class2prefix($namespace) || '';
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

    my $parent  = $c->tree;
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

    my $uid = $parent->getUID;
    $c->actions->{private}->{$uid}->{$method} = [ $namespace, $code ];
    my $forward = $prefix ? "$prefix/$method" : $method;

    if ( $flags{path} ) {
        $flags{path} =~ s/^\w+//;
        $flags{path} =~ s/\w+$//;
        if ( $flags{path} =~ /^'(.*)'$/ ) { $flags{path} = $1 }
        if ( $flags{path} =~ /^"(.*)"$/ ) { $flags{path} = $1 }
    }

    if ( $flags{regex} ) {
        $flags{regex} =~ s/^\w+//;
        $flags{regex} =~ s/\w+$//;
        if ( $flags{regex} =~ /^'(.*)'$/ ) { $flags{regex} = $1 }
        if ( $flags{regex} =~ /^"(.*)"$/ ) { $flags{regex} = $1 }
    }

    my $reverse = $prefix ? "$prefix/$method" : $method;

    if ( $flags{local} || $flags{global} || $flags{path} ) {
        my $path     = $flags{path} || $method;
        my $absolute = 0;

        if ( $path =~ /^\/(.+)/ ) {
            $path     = $1;
            $absolute = 1;
        }

        $absolute = 1 if $flags{global};
        my $name = $absolute ? $path : $prefix ? "$prefix/$path" : $path;
        $c->actions->{plain}->{$name} = [ $namespace, $code ];
    }

    if ( my $regex = $flags{regex} ) {
        push @{ $c->actions->{compiled} }, [ $regex, qr#$regex# ];
        $c->actions->{regex}->{$regex} = [ $namespace, $code ];
    }

    $c->actions->{reverse}->{"$code"} = $reverse;
}

=item $class->setup_actions($component)

Setup actions for a component.

=cut

sub setup_actions {
    my ( $self, $comps ) = @_;

    # These are the core structures
    $self->actions(
        {
            plain    => {},
            private  => {},
            regex    => {},
            compiled => [],
            reverse  => {}
        }
    );

    # We use a tree
    $self->tree( Tree::Simple->new( 0, Tree::Simple->ROOT ) );

    for my $comp (@$comps) {
        $comp = ref $comp || $comp;

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
                        $self->set_action( $name, $code, $comp, $attrs );
                        last;
                    }

                }

            }

        }

    }

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
            my ( $class, $code ) = @{ $actions->{private}->{$uid}->{$action} };
            $privates->addRow( "$prefix$action", $class );
        }

        $walker->( $walker, $_, $prefix ) for $parent->getAllChildren;
    };

    $walker->( $walker, $self->tree, '' );
    $self->log->debug( 'Loaded private actions', $privates->draw )
      if ( @{ $privates->{tbl_rows} } && $self->debug );

    my $publics = Text::ASCIITable->new;
    $publics->setCols( 'Public', 'Private' );
    $publics->setColWidth( 'Public',  36, 1 );
    $publics->setColWidth( 'Private', 37, 1 );

    for my $plain ( sort keys %{ $actions->{plain} } ) {
        my ( $class, $code ) = @{ $actions->{plain}->{$plain} };
        my $reverse = $self->actions->{reverse}->{$code};
        $reverse = $reverse ? "/$reverse" : $code;
        $publics->addRow( "/$plain", $reverse );
    }

    $self->log->debug( 'Loaded public actions', $publics->draw )
      if ( @{ $publics->{tbl_rows} } && $self->debug );

    my $regexes = Text::ASCIITable->new;
    $regexes->setCols( 'Regex', 'Private' );
    $regexes->setColWidth( 'Regex',   36, 1 );
    $regexes->setColWidth( 'Private', 37, 1 );

    for my $regex ( sort keys %{ $actions->{regex} } ) {
        my ( $class, $code ) = @{ $actions->{regex}->{$regex} };
        my $reverse = $self->actions->{reverse}->{$code};
        $reverse = $reverse ? "/$reverse" : $code;
        $regexes->addRow( $regex, $reverse );
    }

    $self->log->debug( 'Loaded regex actions', $regexes->draw )
      if ( @{ $regexes->{tbl_rows} } && $self->debug );
}

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
