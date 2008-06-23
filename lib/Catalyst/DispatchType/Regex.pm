package Catalyst::DispatchType::Regex;

use Moose;
extends 'Catalyst::DispatchType::Path';
use Text::SimpleTable;
use Text::Balanced ();

has _compiled => (is => 'rw', isa => 'ArrayRef', required => 1, default => sub{[]});

=head1 NAME

Catalyst::DispatchType::Regex - Regex DispatchType

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=head2 $self->list($c)

Output a table of all regex actions, and their private equivalent.

=cut

sub list {
    my ( $self, $c ) = @_;
    my @regexes = @{ $self->_compiled };
    return unless @regexes;
    my $re = Text::SimpleTable->new( [ 35, 'Regex' ], [ 36, 'Private' ] );
    for my $regex ( @regexes ) {
        my $action = $regex->{action};
        $re->row( $regex->{path}, "/$action" );
    }
    $c->log->debug( "Loaded Regex actions:\n" . $re->draw . "\n" );
}

=head2 $self->match( $c, $path )

Checks path against every compiled regex, and offers the action for any regex
which matches a chance to match the request. If it succeeds, sets action,
match and captures on $c->req and returns 1. If not, returns 0 without
altering $c.

=cut

override match => sub {
    my ( $self, $c, $path ) = @_;

    return if super();

    # Check path against plain text first

    foreach my $compiled ( @{ $self->_compiled } ) {
        if ( my @captures = ( $path =~ $compiled->{re} ) ) {
            next unless $compiled->{action}->match($c);
            $c->req->action( $compiled->{path} );
            $c->req->match($path);
            $c->req->captures( \@captures );
            $c->action( $compiled->{action} );
            $c->namespace( $compiled->{action}->namespace );
            return 1;
        }
    }

    return 0;
};

=head2 $self->register( $c, $action )

Registers one or more regex actions for an action object.
Also registers them as literal paths.

Returns 1 if any regexps were registered.

=cut

sub register {
    my ( $self, $c, $action ) = @_;
    my $attrs    = $action->attributes;
    my @register = @{ $attrs->{'Regex'} || [] };

    foreach my $r (@register) {
        $self->register_path( $c, $r, $action );
        $self->register_regex( $c, $r, $action );
    }

    return 1 if @register;
    return 0;
}

=head2 $self->register_regex($c, $re, $action)

Register an individual regex on the action. Usually called from the
register method.

=cut

sub register_regex {
    my ( $self, $c, $re, $action ) = @_;
    push(
        @{ $self->_compiled },    # and compiled regex for us
        {
            re     => qr#$re#,
            action => $action,
            path   => $re,
        }
    );
}

=head2 $self->uri_for_action($action, $captures)

returns a URI for this action if it can find a regex attributes that contains
the correct number of () captures. Note that this may function incorrectly
in the case of nested captures - if your regex does (...(..))..(..) you'll
need to pass the first and third captures only.

=cut

sub uri_for_action {
    my ( $self, $action, $captures ) = @_;

    if (my $regexes = $action->attributes->{Regex}) {
        REGEX: foreach my $orig (@$regexes) {
            my $re = "$orig";
            $re =~ s/^\^//;
            $re =~ s/\$$//;
            my $final = '/';
            my @captures = @$captures;
            while (my ($front, $rest) = split(/\(/, $re, 2)) {
                ($rest, $re) =
                    Text::Balanced::extract_bracketed("(${rest}", '(');
                next REGEX unless @captures;
                $final .= $front.shift(@captures);
            }
            next REGEX if @captures;
            return $final;
         }
    }
    return undef;
}

=head1 AUTHOR

Matt S Trout
Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
