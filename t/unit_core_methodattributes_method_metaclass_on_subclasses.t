use strict;
use Test::More;

{
    package NoAttributes::CT;
    use Moose;
    BEGIN { extends qw/Catalyst::Controller/; };

    sub test {}
}
{
    package NoAttributes::RT;
    use Moose;
    extends qw/Catalyst::Controller/;

    sub test {}
}
my $c = 0;
foreach my $class (qw/ CT RT /) {
    my $class_name = 'NoAttributes::' . $class;
    my $meta = $class_name->meta;
    my $meth = $meta->find_method_by_name('test');
    {
        local $TODO = "Known MX::MethodAttributes issue" if $c++;
        ok $meth->can('attributes'), 'method metaclass has ->attributes method for ' . $class;;
    }
}

done_testing;

