package TestContentNegotiation::Controller::Root;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub start :Chained(/) PathPrefix CaptureArgs(0) { }

    sub is_json       : Chained('start') PathPart('') Consumes('application/json') Args(0) { pop->res->body('is_json1') }
    sub is_urlencoded : Chained('start') PathPart('') Consumes('application/x-www-form-urlencoded') Args(0) { pop->res->body('is_urlencoded1') }
    sub is_multipart  : Chained('start') PathPart('') Consumes('multipart/form-data') Args(0) { pop->res->body('is_multipart1') }
      
    sub under :Chained('start') CaptureArgs(0) { }

      sub is_json_under       : Chained('under') PathPart('') Consumes(JSON) Args(0) { pop->res->body('is_json2') }
      sub is_urlencoded_under : Chained('under') PathPart('') Consumes(UrlEncoded) Args(0) { pop->res->body('is_urlencoded2') }
      sub is_multipart_under  : Chained('under') PathPart('') Consumes(Multipart) Args(0) { pop->res->body('is_multipart2') }

      ## Or allow more than one type
    
    sub multi :Chained('start') PathPart('') CaptureArgs(0) { }
      
    sub is_more_than_one_1
      : Chained('multi') 
      : Consumes('application/x-www-form-urlencoded')
      : Consumes('multipart/form-data')
      : Args(0)
    {
      pop->res->body('formdata1');
    }

    sub is_more_than_one_2
      : Chained('multi') 
      : Consumes('HTMLForm')
      : Args(0)
    {
      pop->res->body('formdata2');
    }

    sub is_more_than_one_3
      : Chained('multi') 
      : Consumes('application/x-www-form-urlencoded,multipart/form-data')
      : Args(0)
    {
      pop->res->body('formdata3');
    }


__PACKAGE__->meta->make_immutable;
