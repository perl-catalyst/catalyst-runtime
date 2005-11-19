package Catalyst::DispatchType::Regex;

use strict;
use base qw/Catalyst::DispatchType::Path/;
use Text::SimpleTable;

=head1 NAME

Catalyst::DispatchType::Regex - Regex DispatchType

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=head2 $self->list($c)

=cut

sub list {
    my ( $self, $c ) = @_;
    my $re = Text::SimpleTable->new( [ 36, 'Regex' ], [ 37, 'Private' ] );
    for my $regex ( @{ $self->{compiled} } ) {
        my $action = $regex->{action};
        $re->row( $regex->{path}, "/$action" );
    }
    $c->log->debug( "Loaded Regex actions:\n" . $re->draw )
      if ( @{ $self->{compiled} } );
}

=head2 $self->match( $c, $path )

=cut

sub match {
    my ( $self, $c, $path ) = @_;

    return if $self->SUPER::match( $c, $path );

    # Check path against plain text first

    foreach my $compiled ( @{ $self->{compiled} || [] } ) {
        if ( my @snippets = ( $path =~ $compiled->{re} ) ) {
            $c->req->action( $compiled->{path} );
            $c->req->match($path);
            $c->req->snippets( \@snippets );
            $c->action( $compiled->{action} );
            $c->namespace( $compiled->{action}->namespace );
            return 1;
        }
    }

    return 0;
}

=head2 $self->register( $c, $action )

=cut

sub register {
    my ( $self, $c, $action ) = @_;
    my $attrs = $action->attributes;
    my @register = map { @{ $_ || [] } } @{$attrs}{ 'Regex', 'Regexp' };
    foreach
      my $r ( map { @{ $_ || [] } } @{$attrs}{ 'LocalRegex', 'LocalRegexp' } )
    {
        unless ( $r =~ s/^\^// ) { $r = "(?:.*?)$r"; }
        push( @register, '^' . $action->namespace . '/' . $r );
    }

    foreach my $r (@register) {
        $self->register_path( $c, $r, $action );
        $self->register_regex( $c, $r, $action );
    }
    return 1 if @register;
    return 0;
}

=head2 $self->register_regex($c, $re, $action)

=cut

sub register_regex {
    my ( $self, $c, $re, $action ) = @_;
    push(
        @{ $self->{compiled} },    # and compiled regex for us
        {
            re     => qr#$re#,
            action => $action,
            path   => $re,
        }
    );
}

=head1 AUTHOR

Matt S Trout
Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
