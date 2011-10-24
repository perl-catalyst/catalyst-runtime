# way too many tests to count
use Test::More;

use strict;
use warnings;

use File::Spec;
use File::Path;

my $libdir = 'test_trash';
local @INC = @INC;
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
    my ($libdir, $appclass, $type, $prefix, $name) = @_;

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
    make_component_file(
        $libdir,
        $appclass,
        $component->{type},
        $component->{prefix},
        $component->{name},
    );
}

my $shut_up_deprecated_warnings = q{
    __PACKAGE__->log(Catalyst::Log->new('fatal'));
};

eval "package $appclass; use Catalyst; $shut_up_deprecated_warnings __PACKAGE__->setup";

is_deeply(
    [ sort $appclass->locate_components ],
    [ map { $appclass . '::' . $_->{prefix} . '::' . $_->{name} } @components ],    'locate_components finds the components correctly'
);

can_ok( $appclass, 'components');

my $complist = $appclass->components;

is(scalar keys %$complist, 24, "Correct number of components loaded");

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
    make_component_file(
        $libdir,
        $appclass,
        $component->{type},
        $component->{prefix},
        $component->{name},
    );
}

SKIP: {
    # FIXME - any backcompat planned?
    skip "search_extra has been removed", 5;
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

    {
        my $config = {
            search_extra => [ '::Extra' ],
            except       => [ "${appclass}::Controller::Foo" ]
        };
        my @components_located = $appclass->locate_components($config);
        my @components_expected;
        for (@components) {
            my $name = $appclass . '::' . $_->{prefix} . '::' . $_->{name};
            push @components_expected, $name if $name ne "${appclass}::Controller::Foo";
        }
        is_deeply(
            [ sort @components_located ],
            [ sort @components_expected ],
            'locate_components finds the components correctly'
        );
    }

    can_ok( $appclass, 'components');

    $complist = $appclass->components;

    is(scalar keys %$complist, 24+1, "Correct number of components loaded");

    ok( !exists $complist->{ "${appclass}::Controller::Foo" }, 'Controller::Foo was skipped' );
    ok( exists $complist->{ "${appclass}::Extra::Foo" }, 'Extra::Foo was loaded' );

    rmtree($libdir);
}

$appclass = "ComponentOnce";

write_component_file([$libdir, $appclass, 'Model'], 'TopLevel', <<EOF);
package ${appclass}::Model::TopLevel;
use base 'Catalyst::Model';
sub COMPONENT {

    my \$self = shift->next::method(\@_);
    no strict 'refs';
    *{\__PACKAGE__ . "::whoami"} = sub { return \__PACKAGE__; };
    *${appclass}::Model::TopLevel::GENERATED::ACCEPT_CONTEXT = sub {
        return bless {}, 'FooBarBazQuux';
    };
    \$self;
}

package ${appclass}::Model::TopLevel::Nested;

sub COMPONENT { die "COMPONENT called in the wrong order!"; }

1;

EOF

write_component_file([$libdir, $appclass, 'Model', 'TopLevel'], 'Nested', <<EOF);
package ${appclass}::Model::TopLevel::Nested;
use base 'Catalyst::Model';

my \$called=0;
no warnings 'redefine';
sub COMPONENT { \$called++;return shift->next::method(\@_); }
sub called { return \$called };
1;

EOF

eval "package $appclass; use Catalyst; __PACKAGE__->setup";

is($@, '', "Didn't load component twice");
is($appclass->model('TopLevel::Nested')->called,1, 'COMPONENT called once');

# FIXME we need a much better way of components being able to generate
#       sub-components of themselves (e.g. bring back expand_component_modules?)
#       as otherwise we _have_ to construct / call the COMPONENT method
#       explicitly to get all the sub-components built for Devel::InnerPackage
#       to find them. See FIXME in Catalyst::IOC::Container
ok($appclass->model('TopLevel::GENERATED'), 'Have generated model');
is(ref($appclass->model('TopLevel::GENERATED')), 'FooBarBazQuux',
    'ACCEPT_CONTEXT in generated inner package fired as expected');

$appclass = "InnerComponent";

{
  package InnerComponent::Controller::Test;
  use base 'Catalyst::Controller';
}

$INC{'InnerComponent/Controller/Test.pm'} = 1;

eval "package $appclass; use Catalyst; __PACKAGE__->setup";

isa_ok($appclass->controller('Test'), 'Catalyst::Controller');

rmtree($libdir);

done_testing;
