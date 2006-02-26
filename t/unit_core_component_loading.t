# 2 initial tests, and 6 per component in the loop below
# (do not forget to update the number of components in test 3 as well)
use Test::More tests => 2 + 6 * 24;

use strict;
use warnings;

use File::Spec;
use File::Path;

my $libdir = 'test_trash';
unshift(@INC, $libdir);

my $appclass = 'TestComponents';
my @components = (
    { type => 'Controller', prefix => 'C', name => 'Bar' },
    { type => 'Controller', prefix => 'C', name => 'Foo::Bar' },
    { type => 'Controller', prefix => 'C', name => 'Foo::Foo::Bar' },
    { type => 'Controller', prefix => 'C', name => 'Foo::Foo::Foo::Bar' },
    { type => 'Controller', prefix => 'Controller', name => 'Bar::Bar::Bar::Foo' },
    { type => 'Controller', prefix => 'Controller', name => 'Bar::Bar::Foo' },
    { type => 'Controller', prefix => 'Controller', name => 'Bar::Foo' },
    { type => 'Controller', prefix => 'Controller', name => 'Foo' },
    { type => 'Model', prefix => 'M', name => 'Bar' },
    { type => 'Model', prefix => 'M', name => 'Foo::Bar' },
    { type => 'Model', prefix => 'M', name => 'Foo::Foo::Bar' },
    { type => 'Model', prefix => 'M', name => 'Foo::Foo::Foo::Bar' },
    { type => 'Model', prefix => 'Model', name => 'Bar::Bar::Bar::Foo' },
    { type => 'Model', prefix => 'Model', name => 'Bar::Bar::Foo' },
    { type => 'Model', prefix => 'Model', name => 'Bar::Foo' },
    { type => 'Model', prefix => 'Model', name => 'Foo' },
    { type => 'View', prefix => 'V', name => 'Bar' },
    { type => 'View', prefix => 'V', name => 'Foo::Bar' },
    { type => 'View', prefix => 'V', name => 'Foo::Foo::Bar' },
    { type => 'View', prefix => 'V', name => 'Foo::Foo::Foo::Bar' },
    { type => 'View', prefix => 'View', name => 'Bar::Bar::Bar::Foo' },
    { type => 'View', prefix => 'View', name => 'Bar::Bar::Foo' },
    { type => 'View', prefix => 'View', name => 'Bar::Foo' },
    { type => 'View', prefix => 'View', name => 'Foo' },
);

sub make_component_file {
    my ($type, $prefix, $name) = @_;

    my $compbase = "Catalyst::${type}";
    my $fullname = "${appclass}::${prefix}::${name}";
    my @namedirs = split(/::/, $name);
    my $name_final = pop(@namedirs);
    my @dir_list = ($libdir, $appclass, $prefix, @namedirs);
    my $dir_ux   = join(q{/}, @dir_list);
    my $dir      = File::Spec->catdir(@dir_list);
    my $file     = File::Spec->catfile($dir, $name_final . '.pm');

    mkpath($dir_ux); # mkpath wants unix '/' seperators :p
    open(my $fh, '>', $file) or die "Could not open file $file for writing: $!";
    print $fh <<EOF;
package $fullname;
use base '$compbase';
sub COMPONENT {
    my \$self = shift->NEXT::COMPONENT(\@_);
    no strict 'refs';
    *{\__PACKAGE__ . "::whoami"} = sub { return \__PACKAGE__; };
    \$self;
}
1;

EOF

    close($fh);
}

foreach my $component (@components) {
    make_component_file($component->{type},
                        $component->{prefix},
                        $component->{name});
}

eval "package $appclass; use Catalyst; __PACKAGE__->setup";

can_ok( $appclass, 'components');

my $complist = $appclass->components;

# the +1 below is for the app class itself
is(scalar keys %$complist, 24+1, "Correct number of components loaded");

foreach (keys %$complist) {

    # Skip the component which happens to be the app itself
    next if $_ eq $appclass;

    my $instance = $appclass->component($_);
    isa_ok($instance, $_);
    can_ok($instance, 'whoami');
    is($instance->whoami, $_);

    if($_ =~ /^${appclass}::(?:V|View)::(.*)/) {
        my $moniker = $1;
        isa_ok($instance, 'Catalyst::View');
        can_ok($appclass->view($moniker), 'whoami');
        is($appclass->view($moniker)->whoami, $_);
    }
    elsif($_ =~ /^${appclass}::(?:M|Model)::(.*)/) {
        my $moniker = $1;
        isa_ok($instance, 'Catalyst::Model');
        can_ok($appclass->model($moniker), 'whoami');
        is($appclass->model($moniker)->whoami, $_);
    }
    elsif($_ =~ /^${appclass}::(?:C|Controller)::(.*)/) {
        my $moniker = $1;
        isa_ok($instance, 'Catalyst::Controller');
        can_ok($appclass->controller($moniker), 'whoami');
        is($appclass->controller($moniker)->whoami, $_);
    }
    else {
        die "Something is wrong with this test, this should"
            . " have been unreachable";
    }
}

rmtree($libdir);
