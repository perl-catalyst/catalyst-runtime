#!/usr/bin/perl
# Fork.pm 
# Copyright (c) 2006 Jonathan Rockway <jrockway@cpan.org>

package TestApp::Controller::Fork;

use strict;
use warnings;
use base 'Catalyst::Controller';
use YAML;

sub fork : Local {
    my ($self, $c, $ls) = @_;
    my ($result, $code) = (undef, 1);

    if(!-e $ls || !-x _){ 
	$result = 'skip';
	$code = 0;
    }
    else {
	$result = system($ls, $ls, $ls) || $!;
	$code = $?;
    }
    
    $c->response->body(Dump({result => $result, code => $code}));
}

sub backticks : Local {
    my ($self, $c, $ls) = @_;
    my ($result, $code) = (undef, 1);
    
    if(!-e $ls || !-x _){ 
	$result = 'skip';
	$code = 0;
    }
    else {
	$result = `$ls $ls $ls` || $!;
	$code = $?;
    }
    
    $c->response->body(Dump({result => $result, code => $code}));
}
  
1;
