package MockApp;

use Test::More tests => 10;
use Cwd;

# Remove all relevant env variables to avoid accidental fail
foreach my $name ( grep { m{^(CATALYST|MOCKAPP)} } keys %ENV ) {
    delete $ENV{ $name };
}

$ENV{ CATALYST_HOME }  = cwd . '/t/mockapp';
$ENV{ MOCKAPP_CONFIG } = $ENV{ CATALYST_HOME } . '/mockapp.pl';

use_ok( 'Catalyst' );

__PACKAGE__->config->{substitutions} = {
    foo => sub { shift; join( '-', @_ ); }
};

__PACKAGE__->setup;

ok( my $conf = __PACKAGE__->config );
is( $conf->{ 'Controller::Foo' }->{ foo }, 'bar' );
is( $conf->{ 'Controller::Foo' }->{ new }, 'key' );
is( $conf->{ 'Model::Baz' }->{ qux },      'xyzzy' );
is( $conf->{ 'Model::Baz' }->{ another },  'new key' );
is( $conf->{ 'view' },                     'View::TT::New' );
is( $conf->{ 'foo_sub' },                  'x-y' );
is( $conf->{ 'literal_macro' },            '__DATA__' );
is( $conf->{ 'environment_macro' },        $ENV{ CATALYST_HOME }.'/mockapp.pl' );
