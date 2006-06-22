package Catalyst::DispatchType::ChildOf;

use strict;
use base qw/Catalyst::DispatchType/;
use Text::SimpleTable;
use Catalyst::ActionChain;
use URI;

=head1 NAME

Catalyst::DispatchType::Path - Path DispatchType

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=head2 $self->list($c)

Debug output for Path Part dispatch points

Matt is an idiot and hasn't implemented this yet.

=cut

#sub list {
#    my ( $self, $c ) = @_;
#    my $paths = Text::SimpleTable->new( [ 35, 'Path' ], [ 36, 'Private' ] );
#    foreach my $path ( sort keys %{ $self->{paths} } ) {
#        foreach my $action ( @{ $self->{paths}->{$path} } ) {
#            $path = "/$path" unless $path eq '/';
#            $paths->row( "$path", "/$action" );
#        }
#    }
#    $c->log->debug( "Loaded Path actions:\n" . $paths->draw )
#      if ( keys %{ $self->{paths} } );
#}

=head2 $self->match( $c, $path )

Matt is an idiot and hasn't documented this yet.

=cut

sub match {
    my ( $self, $c, $path ) = @_;

    return 0 if @{$c->req->args};

    my @parts = split('/', $path);

    my ($chain, $captures) = $self->recurse_match($c, '/', \@parts);

    return 0 unless $chain;

    my $action = Catalyst::ActionChain->from_chain($chain);

    $c->req->action("/${action}");
    $c->req->match("/${action}");
    $c->req->captures($captures);
    $c->action($action);
    $c->namespace( $action->namespace );

    return 1;
}

=head2 $self->recurse_match( $c, $parent, \@path_parts )

Matt is an idiot and hasn't documented this yet.

=cut

sub recurse_match {
    my ( $self, $c, $parent, $path_parts ) = @_;
    my $children = $self->{children_of}{$parent};
    return () unless $children;
    my @captures;
    TRY: foreach my $try_part (sort length, keys %$children) {
        my @parts = @$path_parts;
        if (length $try_part) { # test and strip PathPart
            next TRY unless
              ($try_part eq join('/', # assemble equal number of parts
                              splice( # and strip them off @parts as well
                                @parts, 0, scalar(split('/', $try_part))
                              )));
        }
        my @try_actions = @{$children->{$try_part}};
        TRY_ACTION: foreach my $action (@try_actions) {
            if (my $args_attr = $action->attributes->{Args}) {
                # XXX alternative non-Args way to identify an endpoint?
                {
                    local $c->req->{arguments} = [ @{$c->req->args}, @parts ];
                    next TRY_ACTION unless $action->match($c);
                }
                push(@{$c->req->args}, @parts);
                return [ $action ], [ ];
            } else {
                my @captures;
                my @parts = @parts; # localise
                if (my $capture_attr = $action->attributes->{Captures}) {
                    # strip Captures into list
                    push(@captures, splice(@parts, 0, $capture_attr->[0]));
                }
                # try the remaining parts against children of this action
                my ($actions, $captures) = $self->recurse_match(
                                             $c, '/'.$action->reverse, \@parts
                                           );
                if ($actions) {
                    return [ $action, @$actions ], [ @captures, @$captures ];
                }
            }
        }
    }
    return ();
}

=head2 $self->register( $c, $action )

Matt is an idiot and hasn't documented this yet.

=cut

sub register {
    my ( $self, $c, $action ) = @_;

    my @child_of_attr = @{ $action->attributes->{ChildOf} || [] };

    return 0 unless @child_of_attr;

    if (@child_of_attr > 2) {
        Catalyst::Exception->throw(
          "Multiple ChildOf attributes not supported registering ${action}"
        );
    }

    my $parent = $child_of_attr[0];

    if (defined($parent) && length($parent)) {
        unless ($parent =~ m/^\//) {
            $parent = '/'.join('/', $action->namespace, $parent);
        }
    } else {
        $parent = '/'.$action->namespace;
    }

    my $children = ($self->{children_of}{$parent} ||= {});

    my @path_part = @{ $action->attributes->{PathPart} || [] };

    my $part = '';

    if (@path_part == 1) {
        $part = (defined $path_part[0] ? $path_part[0] : $action->name);
    } elsif (@path_part > 1) {
        Catalyst::Exception->throw(
          "Multiple PathPart attributes not supported registering ${action}"
        );
    }

    unshift(@{ $children->{$part} ||= [] }, $action);

}

=head2 $self->uri_for_action($action, $captures)

Matt is an idiot and hasn't documented this yet.

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
