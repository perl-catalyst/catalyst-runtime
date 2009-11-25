package Catalyst::Script::Test;
use Moose;
use Catalyst::Test ();
use namespace::autoclean;

with 'Catalyst::ScriptRole';

__PACKAGE__->meta->get_attribute('help')->cmd_aliases('h');

sub run {
    my $self = shift;

    Catalyst::Test->import($self->application_name);

    print request($ARGV[0])->content  . "\n";

}


__PACKAGE__->meta->make_immutable;

=head1 NAME

Catalyst::Script::Test - Test Catalyst application on the command line

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

FIXME

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
