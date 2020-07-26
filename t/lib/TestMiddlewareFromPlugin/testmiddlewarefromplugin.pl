use Plack::Middleware::Static;

my $static = Plack::Middleware::Static->new(
  path => qr{^/static/}, root => TestMiddlewareFromPlugin->path_to('share'));

my $conf = +{
  'Controller::Root', { namespace => '' },
  'psgi_middleware', [
    $static,
    'Static', { path => qr{^/static2/}, root => TestMiddlewareFromPlugin->path_to('share') },
    'Runtime',
    '+TestMiddleware::Custom', { path => qr{^/static3/}, root => TestMiddlewareFromPlugin->path_to('share') },
    sub {
      my $app = shift;
      return sub {
        my $env = shift;
        if($env->{PATH_INFO} =~m/forced/) {
          Plack::App::File->new(file=>TestMiddlewareFromPlugin->path_to(qw/share static forced.txt/))
            ->call($env);
        } else {
          return $app->($env);
        }
      },
    },

  ],
};
