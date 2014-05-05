package TestLogger;
use strict;
use warnings;

our @LOGS;
our @ILOGS;
our @ELOGS;

sub new {
    return bless {}, __PACKAGE__;
}

sub debug {
    shift;
    push(@LOGS, shift());
}

sub info {
    shift;
    push(@ILOGS, shift());
}

sub warn {
    shift;
    push(@ELOGS, shift());
}

1;

