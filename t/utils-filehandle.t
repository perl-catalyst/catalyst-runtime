#!perl
use strict;
use warnings;
use Test::More tests => 13;

BEGIN { use_ok 'Catalyst::Utils' }

use File::Temp;
use HTTP::Date;
use Data::Dumper;

my %mime = (zip => 'application/zip',
            pdf => 'application/pdf',
            tex => 'application/x-tex',
            epub => 'application/x-epub+zip',
            randomx => 'text/plain', # random extension will get text/plain
            html => 'text/html');

foreach my $ext (keys %mime) {
    my $fh = File::Temp->new(TEMPLATE => "XXXXXXXXX",
                             TMPDIR => 1,
                             SUFFIX => '.' . $ext);
    my $expected_path = $fh->filename;
    print $fh "xx";
    close $fh;
    my $expected_date = time2str((stat($fh->filename))[9]);
    my $expected_mime = $mime{$ext};
    my ($fhx, %headers) =
      Catalyst::Utils::filehandle_response_at_path($fh->filename);
    is ($fhx->path, $fh->filename, "Path ok");
    is_deeply (\%headers, {
                           last_modified => $expected_date,
                           content_type => $expected_mime,
                          }, "headers ok") or diag(Dumper(\%headers));
}
