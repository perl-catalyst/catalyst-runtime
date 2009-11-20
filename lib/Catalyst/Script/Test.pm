package Catalyst::Script::Test;
use Moose;
use namespace::autoclean;

with 'Catalyst::ScriptRole';

sub run {
    my $self = shift;

    Class::MOP::load_class("Catalyst::Test");
    Catalyst::Test->import($self->application_name);

    print request($ARGV[1])->content  . "\n";

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
