package TestLogger;
use strict;
use warnings;

our @LOGS;
our @ELOGS;

sub new {
    return bless {}, __PACKAGE__;
}

sub debug {
    shift;
    push(@LOGS, shift());
}

sub warn {
    shift;
    push(@ELOGS, shift());
}

1;

