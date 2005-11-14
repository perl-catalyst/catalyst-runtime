#!/usr/bin/perl

package HTTP::Headers::ReadOnly;
use base qw/HTTP::Headers/;

use strict;
use warnings;

use Carp qw/croak/;
use Class::Inspector;

sub _jerk_it {
	croak "Can't modify headers after headers have been sent to the client";
}

sub _header {
	my ( $self, $field, $val, $op ) = @_;
	shift;
	_jerk_it if $val;

	$self->SUPER::_header(@_);
}

BEGIN {
	for ( @{ Class::Inspector->functions( "HTTP::Headers" ) }) {
		no strict 'refs';
		*$_ = \&_jerk_it if /remove|clear/;
		
	}
}

__PACKAGE__;

__END__

=pod

=head1 NAME

HTTP::Headers::ReadOnly - Immutable HTTP::headers

=head1 SYNOPSIS

	my $headers = HTTP::Headers->new(...);

	bless $headers, "HTTP::Headers::ReadOnly";

	$headers->content_type( "foo" ); # dies

=head1 DESCRIPTION

This class blocks write access to a L<HTTP::Headers> object.

It is used to raise errors in L<Catalyst> if the header object is modified
after C<finalize_headers>.

=cut


