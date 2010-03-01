package TestAppEncoding::Controller::Root;
use strict;
use warnings;
use base 'Catalyst::Controller';
use Test::More;

__PACKAGE__->config->{namespace} = '';

sub binary : Local {
    my ($self, $c) = @_;
    $c->res->body(do { 
        open(my $fh, '<', $c->path_to('..', '..', 'catalyst_130pix.gif')) or die $!; 
        binmode($fh); 
        local $/ = undef; <$fh>;
    });
}

sub binary_utf8 : Local {
    my ($self, $c) = @_;
    $c->forward('binary');
    my $str = $c->res->body;
    utf8::upgrade($str);
    ok utf8::is_utf8($str), 'Body is variable width encoded string';
    $c->res->body($str);
}

# called by t/aggregate/catalyst_test_utf8.t
sub utf8_non_ascii_content : Local {
    use utf8;
    my ($self, $c) = @_;
    
    my $str = 'ʇsʎlɐʇɐɔ';  # 'catalyst' flipped at http://www.revfad.com/flip.html
    ok utf8::is_utf8($str), '$str is in UTF8 internally';
    
    # encode $str into a sequence of octets and turn off the UTF-8 flag, so that
    # we don't get the 'Wide character in syswrite' error in Catalyst::Engine
    utf8::encode($str);
    ok !utf8::is_utf8($str), '$str is a sequence of octets (byte string)';
    
    $c->res->body($str);
}


sub end : Private {
    my ($self,$c) = @_;
}

1;
