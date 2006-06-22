package Catalyst::DispatchType::Chained;

use strict;
use base qw/Catalyst::DispatchType/;
use Text::SimpleTable;
use Catalyst::ActionChain;
use URI;

# please don't perltidy this. hairy code within.

=head1 NAME

Catalyst::DispatchType::Chained - Path Part DispatchType

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=head2 $self->list($c)

Debug output for Path Part dispatch points

=cut

sub list {
    my ( $self, $c ) = @_;

    return unless $self->{endpoints};

    my $paths = Text::SimpleTable->new(
                    [ 35, 'Path Spec' ], [ 36, 'Private' ]
                );

    ENDPOINT: foreach my $endpoint (
                  sort { $a->reverse cmp $b->reverse }
                           @{ $self->{endpoints} }
                  ) {
        my $args = $endpoint->attributes->{Args}->[0];
        my @parts = (defined($args) ? (("*") x $args) : '...');
        my @parents = ();
        my $parent = "DUMMY";
        my $curr = $endpoint;
        while ($curr) {
            if (my $cap = $curr->attributes->{Captures}) {
                unshift(@parts, (("*") x $cap->[0]));
            }
            if (my $pp = $curr->attributes->{PartPath}) {
                unshift(@parts, $pp->[0])
                    if (defined $pp->[0] && length $pp->[0]);
            }
            $parent = $curr->attributes->{Chained}->[0];
            $curr = $self->{actions}{$parent};
            unshift(@parents, $curr) if $curr;
        }
        next ENDPOINT unless $parent eq '/'; # skip dangling action
        my @rows;
        foreach my $p (@parents) {
            my $name = "/${p}";
            if (my $cap = $p->attributes->{Captures}) {
                $name .= ' ('.$cap->[0].')';
            }
            unless ($p eq $parents[0]) {
                $name = "-> ${name}";
            }
            push(@rows, [ '', $name ]);
        }
        push(@rows, [ '', (@rows ? "=> " : '')."/${endpoint}" ]);
        $rows[0][0] = join('/', '', @parts);
        $paths->row(@$_) for @rows;
    }

    $c->log->debug( "Loaded Path Part actions:\n" . $paths->draw );
}

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
    TRY: foreach my $try_part (sort { length($a) <=> length($b) }
                                   keys %$children) {
        my @parts = @$path_parts;
        if (length $try_part) { # test and strip PathPart
            next TRY unless
              ($try_part eq join('/', # assemble equal number of parts
                              splice( # and strip them off @parts as well
                                @parts, 0, scalar(@{[split('/', $try_part)]})
                              ))); # @{[]} to avoid split to @_
        }
        my @try_actions = @{$children->{$try_part}};
        TRY_ACTION: foreach my $action (@try_actions) {
            if (my $capture_attr = $action->attributes->{Captures}) {
                my @captures;
                my @parts = @parts; # localise

                # strip Captures into list
                push(@captures, splice(@parts, 0, $capture_attr->[0]));

                # try the remaining parts against children of this action
                my ($actions, $captures) = $self->recurse_match(
                                             $c, '/'.$action->reverse, \@parts
                                           );
                if ($actions) {
                    return [ $action, @$actions ], [ @captures, @$captures ];
                }
            } else {
                {
                    local $c->req->{arguments} = [ @{$c->req->args}, @parts ];
                    next TRY_ACTION unless $action->match($c);
                }
                push(@{$c->req->args}, @parts);
                return [ $action ], [ ];
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

    my @child_of_attr = @{ $action->attributes->{Chained} || [] };

    return 0 unless @child_of_attr;

    if (@child_of_attr > 2) {
        Catalyst::Exception->throw(
          "Multiple Chained attributes not supported registering ${action}"
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

    $action->attributes->{Chained} = [ $parent ];

    my $children = ($self->{children_of}{$parent} ||= {});

    my @path_part = @{ $action->attributes->{PathPart} || [] };

    my $part = $action->name;

    if (@path_part == 1 && defined $path_part[0]) {
        $part = $path_part[0];
    } elsif (@path_part > 1) {
        Catalyst::Exception->throw(
          "Multiple PathPart attributes not supported registering ${action}"
        );
    }

    $action->attributes->{PartPath} = [ $part ];

    unshift(@{ $children->{$part} ||= [] }, $action);

    ($self->{actions} ||= {})->{'/'.$action->reverse} = $action;

    unless ($action->attributes->{Captures}) {
        unshift(@{ $self->{endpoints} ||= [] }, $action);
    }

    return 1;
}

=head2 $self->uri_for_action($action, $captures)

Matt is an idiot and hasn't documented this yet.

=cut

sub uri_for_action {
    my ( $self, $action, $captures ) = @_;

    return undef unless ($action->attributes->{Chained}
                           && $action->attributes->{Args});

    my @parts = ();
    my @captures = @$captures;
    my $parent = "DUMMY";
    my $curr = $action;
    while ($curr) {
        if (my $cap = $curr->attributes->{Captures}) {
            return undef unless @captures >= $cap->[0]; # not enough captures
            unshift(@parts, splice(@captures, -$cap->[0]));
        }
        if (my $pp = $curr->attributes->{PartPath}) {
            unshift(@parts, $pp->[0])
                if (defined $pp->[0] && length $pp->[0]);
        }
        $parent = $curr->attributes->{Chained}->[0];
        $curr = $self->{actions}{$parent};
    }

    return undef unless $parent eq '/'; # fail for dangling action

    return undef if @captures; # fail for too many captures

    return join('/', '', @parts);
   
}

=head1 AUTHOR

Matt S Trout <mst@shadowcatsystems.co.uk>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
