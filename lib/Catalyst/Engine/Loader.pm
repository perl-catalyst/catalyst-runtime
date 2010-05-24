package Catalyst::Engine::Loader;
use Moose;
use Catalyst::Exception;
use namespace::autoclean;

extends 'Plack::Loader';

around guess => sub {
    my ($orig, $self) = (shift, shift);
    my $engine = $self->$orig(@_);
    if ($engine eq 'Standalone') {
        if ( $ENV{MOD_PERL} ) {
            my ( $software, $version ) =
                $ENV{MOD_PERL} =~ /^(\S+)\/(\d+(?:[\.\_]\d+)+)/;

            $version =~ s/_//g;
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
    }
    return $engine;
};

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
1;
