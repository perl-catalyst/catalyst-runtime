#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 14;

use lib "t/lib";

BEGIN { use_ok("Catalyst::Utils") };

{
    package This::Module::Is::Not::In::Inc::But::Does::Exist;
    sub moose {};
}

my $warnings = 0;
$SIG{__WARN__} = sub { $warnings++ };

ok( !Class::Inspector->loaded("TestApp::View::Dump"), "component not yet loaded" );

Catalyst::Utils::ensure_class_loaded("TestApp::View::Dump");

ok( Class::Inspector->loaded("TestApp::View::Dump"), "loaded ok" );
is( $warnings, 0, "no warnings emitted" );

$warnings = 0;

Catalyst::Utils::ensure_class_loaded("TestApp::View::Dump");
is( $warnings, 0, "calling again doesn't reaload" );

ok( !Class::Inspector->loaded("TestApp::View::Dump::Request"), "component not yet loaded" );

Catalyst::Utils::ensure_class_loaded("TestApp::View::Dump::Request");
ok( Class::Inspector->loaded("TestApp::View::Dump::Request"), "loaded ok" );

is( $warnings, 0, "calling again doesn't reaload" );

undef $@;
eval { Catalyst::Utils::ensure_class_loaded("This::Module::Is::Probably::Not::There") };
ok( $@, "doesn't defatalize" );
like( $@, qr/There\.pm.*\@INC/, "error looks right" );

$@ = "foo";
Catalyst::Utils::ensure_class_loaded("TestApp::View::Dump::Response");
is( $@, "foo", '$@ is untouched' );

undef $@;
eval { Catalyst::Utils::ensure_class_loaded("This::Module::Is::Not::In::Inc::But::Does::Exist") };
ok( !$@, "no error when loading non existent .pm that *does* have a symbol table entry" ); 

undef $@;
eval { Catalyst::Utils::ensure_class_loaded('Silly::File::.#Name') };
like($@, qr/Malformed class Name/, 'errored when attempting to load a file beginning with a .');

undef $@;
eval { Catalyst::Utils::ensure_class_loaded('Silly::File::Name.pm') };
like($@, qr/Malformed class Name/, 'errored sanely when given a classname ending in .pm');

