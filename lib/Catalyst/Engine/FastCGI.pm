package Catalyst::Engine::FastCGI;

use strict;
use base 'Catalyst::Engine::CGI';
use FCGI;

=head1 NAME

Catalyst::Engine::FastCGI - FastCGI Engine

=head1 DESCRIPTION

This is the FastCGI engine.

=head1 OVERLOADED METHODS

This class overloads some methods from C<Catalyst::Engine::CGI>.

=over 4

=item $self->run($c, $listen, { option => value, ... })
 
Starts the FastCGI server.  If C<$listen> is set, then it specifies a
location to listen for FastCGI requests;

  Form            Meaning
  /path           listen via Unix sockets on /path
  :port           listen via TCP on port on all interfaces
  hostname:port   listen via TCP on port bound to hostname

Options may also be specified;

  Option          Meaning
  leave_umask     Set to 1 to disable setting umask to 0
                  for socket open
  nointr          Do not allow the listener to be
                  interrupted by Ctrl+C
  nproc           Specify a number of processes for
                  FCGI::ProcManager

=cut

sub run {
    my ( $self, $class, $listen, $options ) = @_;

    my $sock;
    if ($listen) {
        my $old_umask = umask;
        unless ( $options->{leave_umask} ) {
            umask(0);
        }
        $sock = FCGI::OpenSocket( $listen, 100 )
          or die "failed to open FastCGI socket; $!";
        unless ( $options->{leave_umask} ) {
            umask($old_umask);
        }
    }
    else {
        -S STDIN
          or die "STDIN is not a socket; specify a listen location";
    }

    $options ||= {};

    my $request =
      FCGI::Request( \*STDIN, \*STDOUT, \*STDERR, \%ENV, $sock,
        ( $options->{nointr} ? 0 : &FCGI::FAIL_ACCEPT_ON_INTR ),
      );

    my $proc_manager;

    if ( $listen and ( $options->{nproc} || 1 ) > 1 ) {
        require FCGI::ProcManager;
        $proc_manager =
          FCGI::ProcManager->new( { n_processes => $options->{nproc} } );
        $proc_manager->pm_manage();
    }

    while ( $request->Accept >= 0 ) {
        $proc_manager && $proc_manager->pm_pre_dispatch();
        $class->handle_request;
        $proc_manager && $proc_manager->pm_pre_dispatch();
    }
}

=item $self->write($c, $buffer)

=cut

sub write {
    my ( $self, $c, $buffer ) = @_;

    unless ( $self->{_prepared_write} ) {
        $self->prepare_write($c);
        $self->{_prepared_write} = 1;
    }

    # FastCGI does not stream data properly if using 'print $handle',
    # but a syswrite appears to work properly.
    *STDOUT->syswrite($buffer);
}

=back

=head1 SEE ALSO

L<Catalyst>, L<FCGI>.

=head1 AUTHORS

Sebastian Riedel, <sri@cpan.org>

Christian Hansen, <ch@ngmedia.com>

Andy Grundman, <andy@hybridized.org>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
