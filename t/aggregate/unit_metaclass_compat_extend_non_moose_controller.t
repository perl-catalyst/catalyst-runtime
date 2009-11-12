use Catalyst ();

{
    package TestApp;
    use base qw/Catalyst/;
}
{
    package TestApp::Controller::Base;
    use base qw/Catalyst::Controller/;
}
{
    package TestApp::Controller::Other;
    use Moose;
    use Test::More tests => 1;
    use Test::Exception;
    lives_ok {
        extends 'TestApp::Controller::Base';
    };
}

