package TestApp::Controller::Engine::Response::PerlIO;

use strict;
use base 'Catalyst::Controller';

sub zip : Relative {
    my ( $self, $c ) = @_;
    
    use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
    
    my $data1 = 'x' x (100 * 1024);
    #my $data2 = join '', map { chr($_) } (0..65535);
    my $data2 = join('', map { chr($_) } (0..255)) x 256;
    
    my $zip = new Archive::Zip;
    $zip->addString(\$data1, 'x.txt', COMPRESSION_LEVEL_BEST_COMPRESSION);
    #$zip->addString(\$data2, 'utf16.txt', COMPRESSION_LEVEL_BEST_COMPRESSION);  ### Needs better support in Archive::Zip first... ###
    $zip->addString(\$data1, 'ASCII.txt', COMPRESSION_LEVEL_BEST_COMPRESSION);
    
    unless ($zip->writeToFileHandle($c->response, 0) == AZ_OK) {
       Catalyst::Exception->throw("ZIP Write Error!");
    }
}

sub csv : Relative {
    my ( $self, $c ) = @_;
    
    use Text::CSV;
    
    my $csv = Text::CSV->new({ eol => "\n" });
    my $csv_doc = [
        [qw/Cnt Item Price/],
        [1, "Box of Ritz Crackers", '$2.55'],
        [1, "Cheese Whiz",          '$1.22'],
        [5, "Banana (single)",      '$ .40'],
    ];
    
    while (my $row = shift @$csv_doc) {
        $csv->print($c->response, $row) || Catalyst::Exception->throw("CSV Write Error!");
    }
}

sub xml : Relative {
    my ( $self, $c ) = @_;
    
    use XML::Simple;
    
    my $xs = XML::Simple->new(
        XMLDecl    => 1,
        KeepRoot   => 1,
        OutputFile => $c->response,
    );
    $xs->xml_out({
        geocode => {
            results => [
                {
                    address_components => [
                        {
                           long_name  => "1600",
                           short_name => "1600",
                           types      => [ "street_number" ]
                        },
                        {
                           long_name  => "Amphitheatre Pkwy",
                           short_name => "Amphitheatre Pkwy",
                           types      => [ "route" ]
                        },
                        {
                           long_name  => "Mountain View",
                           short_name => "Mountain View",
                           types      => [ "locality", "political" ]
                        },
                        {
                           long_name  => "Santa Clara",
                           short_name => "Santa Clara",
                           types      => [ "administrative_area_level_2", "political" ]
                        },
                        {
                           long_name  => "California",
                           short_name => "CA",
                           types      => [ "administrative_area_level_1", "political" ]
                        },
                        {
                           long_name  => "United States",
                           short_name => "US",
                           types      => [ "country", "political" ]
                        },
                        {
                           long_name  => "94043",
                           short_name => "94043",
                           types      => [ "postal_code" ]
                        }
                     ],
                     formatted_address => "1600 Amphitheatre Pkwy, Mountain View, CA 94043, USA",
                     geometry => {
                        location => {
                           lat => 37.42109430,
                           lng => -122.08525150
                        },
                        location_type => "ROOFTOP",
                        viewport => {
                           northeast => {
                              lat => 37.42244328029150,
                              lng => -122.0839025197085
                           },
                           southwest => {
                              lat => 37.41974531970850,
                              lng => -122.0866004802915
                           }
                        }
                     },
                     types => [ "street_address" ]
                }
           ],
           status => "OK",
           source => 'http://maps.googleapis.com/maps/api/geocode/json?address=1600+Amphitheatre+Parkway,+Mountain+View,+CA&sensor=false'
        },
    }) || Catalyst::Exception->throw("XML Write Error!");
}

1;
