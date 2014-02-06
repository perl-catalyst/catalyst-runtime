use warnings;
use strict;
use Test::More;

plan skip_all => "Test Cases are Sketch for next release";

__END__

# Test case to check that we now send scalar and filehandle like
# bodys directly to the PSGI engine, rather than call $writer->write
# or unroll the filehandle ourselves.

{
  package MyApp::Controller::User;

  use base 'Catalyst::Controller';
  use JSON::MaybeXS;

  my %user = (
    name => 'John',
    age => 44,
  );


  sub get_user :Chained(/) PathPrefix CaptureArgs(0)
  {
    pop->stash(user=>\%user);
  }

    sub show :GET Chained(get_user) PathPart('') Args(0)      {
      my ($self, $c) = @_;
      my $user = $c->stash->{user};
      $c->res->format(
        'application/json' => sub { encode_json $user },
        'text/html' => sub { "<p>Hi I'm $user->{name} and my age is $user->{age}</p>" }
      );
    }

    sub post_user :POST Chained(root) PathPart('') Args(0) Consumes(HTMLForm,JSON)
    {
        my ($self, $c) = @_;
        %user = (%user, %{$c->req->body_data});
        $c->res->status(201);
        $c->res->location($c->uri_for( $self->action_for('show')));
    }

  $INC{'MyApp/Controller/User.pm'} = __FILE__;

  package MyApp;
  use Catalyst;

  use HTTP::Headers::ActionPack;
   
  my $cn = HTTP::Headers::ActionPack->new
    ->get_content_negotiator;
   
  sub Catalyst::Response::format
  {
    my $self = shift;
    my %formats = @_;
    my @formats = keys %formats;
   
    my $accept = $self->_context->req->header('Accept') ||
      $format{default} ||
       $_[0];
   
    $self->headers->header('Vary' => 'Accept');
    $self->headers->header('Accepts' => (join ',', @formats));
   
    if(my $which = $cn->choose_media_type(\@formats, $accept)) {
      $self->content_type($which);
      if(my $possible_body = $formats{$which}->($self)) {
        $self->body($possible_body) unless $self->has_body || $self->has_write_fh;
      }
    } else {
      $self->status(406);
      $self->body("Method Not Acceptable");      
    }
  }


  MyApp->setup;
}




use HTTP::Request::Common;
use Catalyst::Test 'MyApp';

ok my($res, $c) = ctx_request('/');

done_testing();
