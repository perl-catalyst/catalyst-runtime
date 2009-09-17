package TestAppToTestScripts;
use strict;
use warnings;

our %RUN_ARGS;

sub run {
    my ($class, %opts) = @_;
    %RUN_ARGS = %opts;
    1; # Does this work?
}

1;

