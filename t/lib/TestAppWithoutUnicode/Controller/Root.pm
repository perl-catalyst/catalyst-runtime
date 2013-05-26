package TestAppWithoutUnicode::Controller::Root;

use Moose;
BEGIN { extends 'Catalyst::Controller' }
use Encode qw(encode_utf8 decode_utf8);

__PACKAGE__->config( namespace => q{} );

sub default : Private {
    my ( $self, $c ) = @_;
    my $param = decode_utf8($c->request->parameters->{'myparam'});
    $c->response->body( encode_utf8($param) );
}

__PACKAGE__->meta->make_immutable;

1;
