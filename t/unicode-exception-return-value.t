use strict;
use warnings;
use Test::More;
use HTTP::Request::Common;

BEGIN {
    package TestApp::Controller::Root;
    $INC{'TestApp/Controller/Root.pm'} = __FILE__;

    use Moose;
    use MooseX::MethodAttributes;
    extends 'Catalyst::Controller';

    sub main :Path('') :Args(1) {
        my ($self, $c, $arg) = @_;
        my $body = $arg . "\n";
        my $query_params = $c->request->query_params;
        my $body_params = $c->request->body_params;
        foreach my $key (sort keys %$query_params) {
            $body .= "Q $key => " . $query_params->{$key} . "\n";
        }
        foreach my $key (sort keys %$body_params) {
            $body .= "B $key => " . $body_params->{$key} . "\n";
        }
        $c->res->body($body);
        $c->res->content_type('text/plain');
    }
    TestApp::Controller::Root->config(namespace => '');
}

{
    package TestApp;
    $INC{'TestApp.pm'} = __FILE__;
 
    use Catalyst;

    sub handle_unicode_encoding_exception {
        my ( $self, $param_value, $error_msg ) = @_;
        # totally dummy: we return any invalid string with a fixed
        # value. a more clever thing would be try to decode it from
        # latin1 or latin2.
        return "INVALID-UNICODE";
    }

    __PACKAGE__->setup;
}
 
 
use Catalyst::Test 'TestApp';

{
    my $res = request('/ok');
    is ($res->content, "ok\n", "app is echoing arguments");
}
 
{
    my $res = request('/%E2%C3%83%C6%92%C3%8');
    is ($res->content, "INVALID-UNICODE\n",
        "replacement ok in arguments");
}
{
    my $res = request('/p?valid_key=%e2');
    is ($res->content, "p\nQ valid_key => INVALID-UNICODE\n",
        "replacement ok in query");
}
{
    my $res = request('/p?%e2=%e2');
    is ($res->content, "p\nQ INVALID-UNICODE => INVALID-UNICODE\n",
        "replacement ok in query");
}
{
    my $req = POST "/p", Content => "%e2=%e2";
    my $res = request($req);
    is ($res->content, "p\nB INVALID-UNICODE => INVALID-UNICODE\n", "replacement ok in body");
}
{
    my $req = POST "/p", Content => "valid_key=%e2";
    my $res = request($req);
    is ($res->content, "p\nB valid_key => INVALID-UNICODE\n", "replacement ok in body");
}
{
    # and a superset of problems:
    my $req = POST "/%e5?%e3=%e3", Content => "%e4=%e4";
    my $res = request($req);
    my $expected = <<'BODY';
INVALID-UNICODE
Q INVALID-UNICODE => INVALID-UNICODE
B INVALID-UNICODE => INVALID-UNICODE
BODY
    is ($res->content, $expected, "Found the replacement strings everywhere");
}


done_testing;

#TestApp->to_app;
