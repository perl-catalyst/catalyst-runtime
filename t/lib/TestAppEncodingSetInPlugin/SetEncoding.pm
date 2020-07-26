package TestAppEncodingSetInPlugin::SetEncoding;
use strict;
use warnings;

sub setup {
    my $c = shift;
    $c->config(encoding => 'UTF-8');
    $c->next::method(@_);
}

1;
