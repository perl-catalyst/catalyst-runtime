package TestAppUnicode::Controller::Root;
use strict;
use warnings;
use utf8;

__PACKAGE__->config(namespace => q{});

use base 'Catalyst::Controller';

sub main :Path('') { 
    my ($self, $ctx, $charset) = @_;
    my $content_type = 'text/html';
    if ($ctx->stash->{charset}) {
        $content_type .= ";charset=" . $ctx->stash->{charset};
    }
    $ctx->res->body('<h1>It works</h1>');
    $ctx->res->content_type($content_type);
}

sub unicode_no_enc :Local {
    my ($self, $c) = @_;
    my $data = "ほげ"; # hoge!
    utf8::encode($data);
    $c->response->body($data);
    $c->res->content_type('text/plain');
    $c->encoding(undef);
}

sub unicode :Local {
    my ($self, $c) = @_;
    my $data = "ほげ"; # hoge!
    $c->response->body($data); # should be decoded
    $c->res->content_type('text/plain');
}

sub not_unicode :Local {
    my ($self, $c) = @_;
    my $data = "\x{1234}\x{5678}";
    utf8::encode($data); # DO NOT WANT unicode
    $c->response->body($data); # just some octets
    $c->res->content_type('text/plain');
    $c->encoding(undef);
}

sub latin1 :Local {
  my ($self, $c) = @_;

  $c->res->content_type('text/plain');
  $c->response->body('LATIN SMALL LETTER E WITH ACUTE: é');
}

sub file :Local {
    my ($self, $c) = @_;
    close *STDERR; # i am evil.
    $c->response->body($main::TEST_FILE); # filehandle from test file
}

sub capture : Chained('/') CaptureArgs(1) {}

sub decode_capture : Chained('capture') PathPart('') Args(0) {
    my ( $self, $c, $cap_arg ) = @_;
    $c->forward('main');
}

sub capture_charset : Chained('/') Args(1) {
    my ( $self, $c, $cap_arg ) = @_;
    $c->stash(charset => $cap_arg);
    $c->forward('main');
}

sub shift_jis :Local {
    my ($self, $c) = @_;
    my $data = "ほげ"; # hoge!
    $c->response->body($data); # should be decoded
    $c->res->content_type('text/plain; charset=Shift_JIS');
    $c->encoding("Shift_JIS");
}

1;

