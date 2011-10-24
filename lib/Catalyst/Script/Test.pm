package Catalyst::Script::Test;
use Moose;
use Catalyst::Test ();
use namespace::autoclean;

with 'Catalyst::ScriptRole';

sub run {
    my $self = shift;

    Catalyst::Test->import($self->application_name);

    foreach my $arg (@{ $self->ARGV }) {
        print request($arg)->content  . "\n";
    }
}


__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Catalyst::Script::Test - Test Catalyst application on the command line

=head1 SYNOPSIS

  myapp_test.pl [options] /path

  Options:
  -h     --help           display this help and exits

=head1 DESCRIPTION

Script to perform a test hit against your application and display the output.

=head1 SEE ALSO

L<Catalyst::ScriptRunner>

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
