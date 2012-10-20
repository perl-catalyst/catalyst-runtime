use strict;
use warnings;

package My::AttributesBaseClass;
use base qw( Catalyst::Controller );

sub fetch : Chained('/') PathPrefix CaptureArgs(0) { }

sub left_alone :Chained('fetch') PathPart Args(0) { }

sub view : PathPart Chained('fetch') Args(0) { }

sub foo { } # no attributes

package TestApp::Controller::Attributes;
use base qw(My::AttributesBaseClass);

sub _parse_MakeMeVisible_attr {
    my ($self, $c, $name, $value) = @_;
    if (!$value){
        return Chained => 'fetch', PathPart => 'all_attrs', Args => 0;
    }
    elsif ($value eq 'some'){
        return Chained => 'fetch', Args => 0;
    }
    elsif ($value eq 'one'){
        return PathPart => 'one_attr';
    }
}

sub view { }    # override attributes to "hide" url

sub foo : Local { }

sub all_attrs_action :MakeMeVisible { }

sub some_attrs_action :MakeMeVisible('some') PathPart('some_attrs') { }

sub one_attr_action :MakeMeVisible('one') Chained('fetch') Args(0) { }

1;
