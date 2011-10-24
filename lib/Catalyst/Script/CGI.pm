package Catalyst::Script::CGI;
use Moose;
use namespace::autoclean;

sub _plack_engine_name { 'CGI' }

with 'Catalyst::ScriptRole';

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Catalyst::Script::CGI - The CGI Catalyst Script

=head1 SYNOPSIS

  myapp_cgi.pl [options]

  Options:
  -?     --help           display this help and exits

=head1 DESCRIPTION

This is a script to run the Catalyst engine specialized for the CGI environment.

=head1 SEE ALSO

L<Catalyst::ScriptRunner>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
