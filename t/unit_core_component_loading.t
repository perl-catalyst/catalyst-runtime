# 2 initial tests, and 6 per component in the loop below
# (do not forget to update the number of components in test 3 as well)
# 5 extra tests for the loading options
# One test for components in inner packages
use Test::More tests => 2 + 6 * 24 + 5 + 1;

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

sub write_component_file { 
  my ($dir_list, $module_name, $content) = @_;

  my $dir  = File::Spec->catdir(@$dir_list);
  my $file = File::Spec->catfile($dir, $module_name . '.pm');

  mkpath(join(q{/}, @$dir_list) );
  open(my $fh, '>', $file) or die "Could not open file $file for writing: $!";
  print $fh $content;
  close $fh;
}

sub make_component_file {
    my ($type, $prefix, $name) = @_;

    my $compbase = "Catalyst::${type}";
    my $fullname = "${appclass}::${prefix}::${name}";
    my @namedirs = split(/::/, $name);
    my $name_final = pop(@namedirs);
    my @dir_list = ($libdir, $appclass, $prefix, @namedirs);

    write_component_file(\@dir_list, $name_final, <<EOF);
package $fullname;
use MRO::Compat;
use base '$compbase';
sub COMPONENT {
    my \$self = shift->next::method(\@_);
    no strict 'refs';
    *{\__PACKAGE__ . "::whoami"} = sub { return \__PACKAGE__; };
    \$self;
}
1;

EOF
}

foreach my $component (@components) {
    make_component_file($component->{type},
                        $component->{prefix},
                        $component->{name});
}

my $shut_up_deprecated_warnings = q{
    __PACKAGE__->log(Catalyst::Log->new('fatal'));
};

eval "package $appclass; use Catalyst; $shut_up_deprecated_warnings __PACKAGE__->setup";

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

# test extra component loading options

$appclass = 'ExtraOptions';
push @components, { type => 'View', prefix => 'Extra', name => 'Foo' };

foreach my $component (@components) {
    make_component_file($component->{type},
                        $component->{prefix},
                        $component->{name});
}

eval qq(
package $appclass;
use Catalyst;
$shut_up_deprecated_warnings
__PACKAGE__->config->{ setup_components } = {
    search_extra => [ '::Extra' ],
    except       => [ "${appclass}::Controller::Foo" ]
};
__PACKAGE__->setup;
);

can_ok( $appclass, 'components');

$complist = $appclass->components;

is(scalar keys %$complist, 24+1, "Correct number of components loaded");

ok( !exists $complist->{ "${appclass}::Controller::Foo" }, 'Controller::Foo was skipped' );
ok( exists $complist->{ "${appclass}::Extra::Foo" }, 'Extra::Foo was loaded' );

rmtree($libdir);

$appclass = "ComponentOnce";

write_component_file([$libdir, $appclass, 'Model'], 'TopLevel', <<EOF);
package ${appclass}::Model::TopLevel;
use base 'Catalyst::Model';
sub COMPONENT {
 
    my \$self = shift->next::method(\@_);
    no strict 'refs';
    *{\__PACKAGE__ . "::whoami"} = sub { return \__PACKAGE__; };
    \$self;
}

package ${appclass}::Model::TopLevel::Nested;

sub COMPONENT { die "COMPONENT called in the wrong order!"; }

1;

EOF

write_component_file([$libdir, $appclass, 'Model', 'TopLevel'], 'Nested', <<EOF);
package ${appclass}::Model::TopLevel::Nested;
use base 'Catalyst::Model';

no warnings 'redefine';
sub COMPONENT { return shift->next::method(\@_); }
1;

EOF

eval "package $appclass; use Catalyst; __PACKAGE__->setup";

is($@, '', "Didn't load component twice");

$appclass = "InnerComponent";

{
  package InnerComponent::Controller::Test;
  use base 'Catalyst::Controller';
}

$INC{'InnerComponent/Controller/Test.pm'} = 1;

eval "package $appclass; use Catalyst; __PACKAGE__->setup";

isa_ok($appclass->controller('Test'), 'Catalyst::Controller');

rmtree($libdir);
