package Catalyst::AttrContainer;

use Moose;
use MooseX::ClassAttribute;
use Catalyst::Exception;

class_has _attr_cache   => (
                            is => 'rw',
                            isa => 'HashRef',
                            required => 1,
                            default => sub{{}}
                           );
class_has _action_cache => (
                            is => 'rw',
                            isa => 'ArrayRef',
                            required => 1,
                            default => sub{ [] }
                          );

# note - see attributes(3pm)
sub MODIFY_CODE_ATTRIBUTES {
    my ( $class, $code, @attrs ) = @_;
    #can't the below just be $class->_attr_cache->{$code} = \@attrs; ?
    $class->_attr_cache( { %{ $class->_attr_cache }, $code => [@attrs] } );
    #why can't this just be push @{$class->_action_cache}, [$code, \@attrs] ?
    $class->_action_cache(
        [ @{ $class->_action_cache }, [ $code, [@attrs] ] ] );
    return ();
}

sub FETCH_CODE_ATTRIBUTES { $_[0]->_attr_cache->{ $_[1] } || () }

=head1 NAME

Catalyst::AttrContainer

=head1 SYNOPSIS

=head1 DESCRIPTION

This class sets up the code attribute cache.  It's a base class for
L<Catalyst::Controller>.

=head1 METHODS

=head2 FETCH_CODE_ATTRIBUTES

Attribute function. See attributes(3pm)

=head2 MODIFY_CODE_ATTRIBUTES

Attribute function. See attributes(3pm)

=head1 SEE ALSO

L<Catalyst::Dispatcher>
L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Marcus Ramberg, C<mramberg@cpan.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
