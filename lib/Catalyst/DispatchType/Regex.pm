package Catalyst::DispatchType::Regex;

use strict;
use base qw/Catalyst::DispatchType::Path/;
use Text::ASCIITable;

=head1 NAME

Catalyst::DispatchType::Regex - Regex DispatchType

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item $self->list($c)

=cut

sub list {
    my ( $self, $c ) = @_;
    my $re = Text::ASCIITable->new;
    $re->setCols( 'Regex', 'Private' );
    $re->setColWidth( 'Regex',   36, 1 );
    $re->setColWidth( 'Private', 37, 1 );
    for my $regex ( @{ $self->{compiled} } ) {
        my $compiled = $regex->{re};
        my $action   = $regex->{action};
        $re->addRow( $compiled, "/$action" );
    }
    $c->log->debug( "Loaded Regex actions:\n" . $re->draw )
      if ( @{ $re->{tbl_rows} } );
}

=item $self->match( $c, $path )

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

=item $self->register( $c, $action )

=cut

sub register {
    my ( $self, $c, $action ) = @_;
    my $attrs = $action->attributes;
    my @register = map { @{ $_ || [] } } @{$attrs}{ 'Regex', 'Regexp' };
    foreach my $r (@register) {
        unless ($r =~ /^\^/) {     # Relative regex
            $r = '^'.$action->namespace.'/'.$r;
        }
        $self->{paths}{$r} = $action;    # Register path for superclass
        push(
            @{ $self->{compiled} },      # and compiled regex for us
            {
                re     => qr#$r#,
                action => $action,
                path   => $r,
            }
        );
    }
}

=back

=head1 AUTHOR

Matt S Trout
Sebastian Riedel, C<sri@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
