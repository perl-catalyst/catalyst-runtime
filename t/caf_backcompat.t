use strict;
use warnings;
use Test::More;
use Test::Exception;
use Class::MOP ();
use Moose::Util ();

# List of everything which used Class::Accessor::Fast in 5.70.
my @modules = qw/
    Catalyst::Action
    Catalyst::ActionContainer
    Catalyst::Component
    Catalyst::Dispatcher
    Catalyst::DispatchType
    Catalyst::Engine::HTTP::Restarter::Watcher
    Catalyst::Engine
    Catalyst::Log
    Catalyst::Request::Upload
    Catalyst::Request
    Catalyst::Response
/;

plan tests => scalar @modules;

foreach my $module (@modules) {
    Class::MOP::load_class($module);
    ok Moose::Util::does_role($module => 'MooseX::Emulate::Class::Accessor::Fast'),
        "$module has Class::Accessor::Fast back-compat";
}
