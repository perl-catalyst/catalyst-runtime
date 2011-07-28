package Catalyst::DispatchType::Path;

use Moose;
extends 'Catalyst::DispatchType';

use Text::SimpleTable;
use Catalyst::Utils;
use URI;

has _paths => (
               is => 'rw',
               isa => 'HashRef',
               required => 1,
               default => sub { +{} },
              );

no Moose;

=head1 NAME

Catalyst::DispatchType::Path - Path DispatchType

=head1 SYNOPSIS

See L<Catalyst::DispatchType>.

=head1 DESCRIPTION

Dispatch type managing full path matching behaviour.  For more information on
dispatch types, see:

=over 4

=item * L<Catalyst::Manual::Intro> for how they affect application authors

=item * L<Catalyst::DispatchType> for implementation information.

=back

=head1 METHODS

=head2 $self->list($c)

Debug output for Path dispatch points

=cut

sub list {
    my ( $self, $c ) = @_;
    my $avail_width = Catalyst::Utils::term_width() - 9;
    my $col1_width = ($avail_width * .50) < 35 ? 35 : int($avail_width * .50);
    my $col2_width = $avail_width - $col1_width;
    my $paths = Text::SimpleTable->new(
       [ $col1_width, 'Path' ], [ $col2_width, 'Private' ]
    );
    foreach my $path ( sort keys %{ $self->_paths } ) {
        foreach my $action ( @{ $self->_paths->{$path} } ) {
            my $args  = $action->attributes->{Args}->[0];
            my $parts = defined($args) ? '/*' x $args : '/...';

            my $display_path = "/$path/$parts";
            $display_path =~ s{/{1,}}{/}g;

            $paths->row( $display_path, "/$action" );
        }
    }
    $c->log->debug( "Loaded Path actions:\n" . $paths->draw . "\n" )
      if ( keys %{ $self->_paths } );
}

=head2 $self->match( $c, $path )

For each action registered to this exact path, offers the action a chance to
match the path (in the order in which they were registered). Succeeds on the
first action that matches, if any; if not, returns 0.

=cut

sub match {
    my ( $self, $c, $path ) = @_;

    $path = '/' if !defined $path || !length $path;

    my @actions = @{ $self->_paths->{$path} || [] };

    foreach my $action ( @actions ) {
        next unless $action->match($c);
        $c->req->action($path);
        $c->req->match($path);
        $c->action($action);
        $c->namespace( $action->namespace );
        return 1;
    }

    return 0;
}

=head2 $self->register( $c, $action )

Calls register_path for every Path attribute for the given $action.

=cut

sub register {
    my ( $self, $c, $action ) = @_;

    my @register = @{ $action->attributes->{Path} || [] };

    $self->register_path( $c, $_, $action ) for @register;

    return 1 if @register;
    return 0;
}

=head2 $self->register_path($c, $path, $action)

Registers an action at a given path.

=cut

sub register_path {
    my ( $self, $c, $path, $action ) = @_;
    $path =~ s!^/!!;
    $path = '/' unless length $path;
    $path = URI->new($path)->canonical;
    $path =~ s{(?<=[^/])/+\z}{};

    $self->_paths->{$path} = [
        sort { $a->compare($b) } ($action, @{ $self->_paths->{$path} || [] })
    ];

    return 1;
}

=head2 $self->uri_for_action($action, $captures)

get a URI part for an action; always returns undef is $captures is set
since Path actions don't have captures

=cut

sub uri_for_action {
    my ( $self, $action, $captures ) = @_;

    return undef if @$captures;

    if (my $paths = $action->attributes->{Path}) {
        my $path = $paths->[0];
        $path = '/' unless length($path);
        $path = "/${path}" unless ($path =~ m/^\//);
        $path = URI->new($path)->canonical;
        return $path;
    } else {
        return undef;
    }
}

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
