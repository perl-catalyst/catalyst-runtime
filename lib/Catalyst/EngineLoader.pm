package Catalyst::EngineLoader;
use Moose;
use Catalyst::Exception;
use Catalyst::Utils;
use namespace::autoclean;

extends 'Plack::Loader';

has application_name => (
    isa => 'Str',
    is => 'ro',
    required => 1,
);

has requested_engine => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_requested_engine',
);

sub needs_psgi_engine_compat_hack {
    my ($self) = @_;
    return $self->has_requested_engine
        && $self->requested_engine eq 'PSGI';
}

has catalyst_engine_class => (
    isa => 'Str',
    is => 'rw',
    lazy => 1,
    builder => '_guess_catalyst_engine_class',
);

sub _guess_catalyst_engine_class {
    my $self = shift;
    my $old_engine = $self->has_requested_engine
        ? $self->requested_engine
        : Catalyst::Utils::env_value($self->application_name, 'ENGINE');
    if (!defined $old_engine) {
        return 'Catalyst::Engine';
    }
    elsif ($old_engine eq 'PSGI') {
        ## If we are running under plackup let the Catalyst::Engine::PSGI
        ## continue to run, but warn.
        warn <<"EOW";
You are running Catalyst::Engine::PSGI, which is considered a legacy engine for
this version of Catalyst.  We will continue running and use your existing psgi
file, but it is recommended to perform the trivial upgrade process, which will
leave you with less code and a forward path.

Please review Catalyst::Upgrading
EOW
        return 'Catalyst::Engine::' . $old_engine;
    }
    elsif ($old_engine =~ /^(CGI|FastCGI|HTTP|Apache.*)$/) {
        return 'Catalyst::Engine';
    }
    else {
        return 'Catalyst::Engine::' . $old_engine;
    }
}

around guess => sub {
    my ($orig, $self) = (shift, shift);
    my $engine = $self->$orig(@_);
    if ( $ENV{MOD_PERL} ) {
        my ( $software, $version ) =
          $ENV{MOD_PERL} =~ /^(\S+)\/(\d+(?:[\.\_]\d+)+)/;
        $version =~ s/_//g;
        $version =~ s/(\.[^.]+)\./$1/g;

        if ( $software eq 'mod_perl' ) {
            if ( $version >= 1.99922 ) {
                $engine = 'Apache2';
            }

            elsif ( $version >= 1.9901 ) {
                Catalyst::Exception->throw( message => 'Plack does not have a mod_perl 1.99 handler' );
                $engine = 'Apache2::MP19';
            }

            elsif ( $version >= 1.24 ) {
                $engine = 'Apache1';
            }

            else {
                Catalyst::Exception->throw( message =>
                      qq/Unsupported mod_perl version: $ENV{MOD_PERL}/ );
            }
        }
    }

    my $old_engine = Catalyst::Utils::env_value($self->application_name, 'ENGINE');
    if (!defined $old_engine) { # Not overridden
    }
    elsif ($old_engine =~ /^(PSGI|CGI|Apache.*)$/) {
        # Trust autodetect
    }
    elsif ($old_engine eq 'HTTP') {
        $engine = 'Standalone';
    }
    elsif ($old_engine eq 'FastCGI') {
        $engine = 'FCGI';
    }
    elsif ($old_engine eq "HTTP::Prefork") { # Too bad if you're customising, we don't handle options
                                             # write yourself a script to collect and pass in the options
        $engine = "Starman";
    }
    elsif ($old_engine eq "HTTP::POE") {
        Catalyst::Exception->throw("HTTP::POE engine no longer works, recommend you use Twiggy instead");
    }
    elsif ($old_engine eq "Zeus") {
        Catalyst::Exception->throw("Zeus engine no longer works");
    }
    else {
        warn("You asked for an unrecognised engine '$old_engine' which is no longer supported, this has been ignored.\n");
    }

    return $engine;
};

# Force constructor inlining
__PACKAGE__->meta->make_immutable( replace_constructor => 1 );

1;

__END__

=head1 NAME

Catalyst::EngineLoader - The Catalyst Engine Loader

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

Wrapper on L<Plack::Loader> which resets the ::Engine if you are using some
version of mod_perl.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=begin Pod::Coverage

needs_psgi_engine_compat_hack

=end Pod::Coverage

=cut
