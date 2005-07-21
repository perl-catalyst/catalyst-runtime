#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Pod::Usage;
use Catalyst::Helper;

my $help  = 0;
my $nonew = 0;

GetOptions( 'help|?' => \$help,
	    'nonew'  => \$nonew );

pod2usage(1) if ( $help || !$ARGV[0] );

my $helper = Catalyst::Helper->new({'.newfiles' => !$nonew});
pod2usage(1) unless $helper->mk_app( $ARGV[0] );

1;
__END__

=head1 NAME

catalyst - Bootstrap a Catalyst application

=head1 SYNOPSIS

catalyst.pl [options] application-name

 Options:
   -help        display this help and exits
   -nonew       don't create a .new file where a file to be created exists

 application-name has to be a valid Perl module name and can include ::

 Examples:
    catalyst.pl My::App
    catalyst.pl MyApp

 See also:
    perldoc Catalyst::Manual
    perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Bootstrap a Catalyst application.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Manual>, L<Catalyst::Manual::Intro>,
L<Catalyst::Test>, L<Catalyst::Request>, L<Catalyst::Response>,
L<Catalyst::Engine>

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 COPYRIGHT

Copyright 2004 Sebastian Riedel. All rights reserved.

This library is free software. You can redistribute it and/or modify it under
the same terms as perl itself.

=cut
