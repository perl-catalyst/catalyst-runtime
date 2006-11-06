package Catalyst::DispatchType::Path;

use strict;
use base qw/Catalyst::DispatchType/;
use Text::SimpleTable;
use URI;

=head1 NAME

Catalyst::DispatchType::Path - Path DispatchType

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=head2 $self->list($c)

Debug output for Path dispatch points

=cut

sub list {
    my ( $self, $c ) = @_;
    my $paths = Text::SimpleTable->new( [ 35, 'Path' ], [ 36, 'Private' ] );
    foreach my $path ( sort keys %{ $self->{paths} } ) {
        my $display_path = $path eq '/' ? $path : "/$path";
        foreach my $action ( @{ $self->{paths}->{$path} } ) {
            $paths->row( $display_path, "/$action" );
        }
    }
    $c->log->debug( "Loaded Path actions:\n" . $paths->draw . "\n" )
      if ( keys %{ $self->{paths} } );
}

=head2 $self->match( $c, $path )

For each action registered to this exact path, offers the action a chance to
match the path (in the order in which they were registered). Succeeds on the
first action that matches, if any; if not, returns 0.

=cut

sub match {
    my ( $self, $c, $path ) = @_;

    $path ||= '/';

    foreach my $action ( @{ $self->{paths}->{$path} || [] } ) {
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

    unshift( @{ $self->{paths}{$path} ||= [] }, $action);

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

=head1 AUTHOR

Matt S Trout
Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
