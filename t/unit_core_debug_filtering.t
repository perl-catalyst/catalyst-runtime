use strict;
use warnings;
use Test::More tests=>15;

use Catalyst;
use HTTP::Headers;
my $c = Catalyst->new( {} );
$c->config(Debug => {param_filters => 'simple_str'});

isa_ok( $c, 'Catalyst' );
my $params = $c->_apply_parameter_debug_filters( 'query', {} );
is_deeply( $params, {}, 'empty param list' );
my $filter_str = '[FILTERED]';

$params = $c->_apply_parameter_debug_filters( 'body', { simple_str => 1, other_str => 2 } );
is( $params->{simple_str}, $filter_str, 'filtered simple_str' );
is( $params->{other_str},  '2',         "didn't filter other_str" );

$c->config( Debug => { param_filters => [qw(a b)] } );
$params = $c->_apply_parameter_debug_filters( 'query', { a => 1, b => 2, c => 3 }, );

is_deeply( $params, { a => $filter_str, b => $filter_str, c => 3 }, 'list of simple param names' );

$c->config( Debug => { param_filters => qr/^foo/ } );
$params = $c->_apply_parameter_debug_filters( 'query', { foo => 1, foobar => 2, c => 3 }, );
is_deeply( $params, { foo => $filter_str, foobar => $filter_str, c => 3 }, 'single regex' );

$c->config(Debug => {param_filters => [qr/^foo/, qr/bar/, 'simple']});
$params = $c->_apply_parameter_debug_filters( 'query', { foo => 1, foobar => 2, bar => 3, c => 3, simple => 4 }, );
is_deeply( $params, { foo => $filter_str, foobar => $filter_str, bar => $filter_str, c => 3, simple => $filter_str }, 'array of regexes and a simple filter' );

$c->config(
    Debug => {
        param_filters => sub { return unless shift eq 'password'; return '*' x 8 }
    }
);
$params = $c->_apply_parameter_debug_filters( 'query', { password => 'secret', other => 'public' }, );
is_deeply( $params, { other => 'public', password => '********' }, 'single CODE ref' );

$c->config( Debug => { param_filters => { body => qr// } } );
$params = $c->_apply_parameter_debug_filters( 'query', { a=>1, b=>2 } );
is_deeply( $params, { a=>1, b=>2 }, 'body filters do not modify query params' );
$params = $c->_apply_parameter_debug_filters( 'body', { a=>1, b=>2 } );
is_deeply( $params, { a => $filter_str, b => $filter_str }, 'all body params filtered' );

$c->config( Debug => { param_filters => undef } );
$c->config( Debug => { param_filters => { all => [qw(foo bar)] } } );
$params = $c->_apply_parameter_debug_filters( 'body', { foo=>1, bar=>2, baz=>3 } );
is_deeply( $params, { foo => $filter_str, bar => $filter_str, baz => 3 }, 'using the "all" type filter on body params' );
$params = $c->_apply_parameter_debug_filters( 'query', { foo=>1, bar=>2, baz=>3 } );
is_deeply( $params, { foo => $filter_str, bar => $filter_str, baz => 3 }, 'using the "all" type filter on query params' );

my $headers = HTTP::Headers->new(
    Content_type => 'text/html',
    Set_Cookie => 'session_id=abc123; expires=Fri, 31-Dec-2010 23:59:59 GMT; path=/; domain=.example.org.',
    Set_Cookie => 'something_else=xyz890; expires=Fri, 31-Dec-2010 23:59:59 GMT; path=/; domain=.example.org.',
);
$c->config(
    Debug => {
        response_header_filters => sub {
            my ( $n, $v ) = @_;
            return unless $n eq 'Set-Cookie';
            $v =~ s/session_id=.*?;/session_id=SECRET/;
            return $v;
        },
    }
);
my $filtered = $c->_apply_header_debug_filters(response => $headers);
is($filtered->header('Content-Type'), 'text/html', 'Content-Type header left alone');
like($filtered->as_string, qr/session_id=SECRET/, 'Set-Cookie value filtered');
like($filtered->as_string, qr/something_else=xyz890/, 'non-session_id cookie not filtered');
