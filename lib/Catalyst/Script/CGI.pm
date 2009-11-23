package Catalyst::Script::CGI;
use Moose;
BEGIN { $ENV{CATALYST_ENGINE} ||= 'CGI' }
use namespace::autoclean;

with 'Catalyst::ScriptRole';

has '+help' => (cmd_aliases => 'h');

__PACKAGE__->meta->make_immutable;

=head1 NAME

Catalyst::Script::CGI - The CGI Catalyst Script

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

This is a script to run the Catalyst engine specialized for the CGI environment.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
