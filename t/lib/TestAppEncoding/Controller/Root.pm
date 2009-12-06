package TestAppEncoding::Controller::Root;
use strict;
use warnings;
use base 'Catalyst::Controller';
use Test::More;

__PACKAGE__->config->{namespace} = '';

sub binary : Local {
    my ($self, $c) = @_;
    $c->res->body(do { open(my $fh, '<', $c->path_to('..', '..', 'catalyst_130pix.gif')) or die $!; binmode($fh); local $/ = undef; <$fh>; });
}

sub binary_utf8 : Local {
    my ($self, $c) = @_;
    $c->forward('binary');
    my $str = $c->res->body;
    utf8::upgrade($str);
    ok utf8::is_utf8($str), 'Body is variable width encoded string';
    $c->res->body($str);
}

sub end : Private {
    my ($self,$c) = @_;
}

1;
