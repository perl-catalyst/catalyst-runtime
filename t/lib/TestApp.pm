package TestApp;

use strict;
use Catalyst qw[Test::Errors Test::Headers];

our $VERSION = '0.01';

TestApp->config(
    name => 'TestApp',
    root => '/Users/chansen/src/MyApp/root',
);

TestApp->setup;

#sub execute { return shift->NEXT::execute(@_); } # does not work, bug?

sub global_action : Private {
    my ( $self, $c ) = @_;
    $c->forward('TestApp::View::Dump::Request');
}

sub execute {
    my $c      = shift;
    my $class  = ref( $c->component( $_[0] ) ) || $_[0];
    my $action = $c->actions->{reverse}->{"$_[1]"} || "$_[1]";

    my $method;

    if ( $action =~ /->(\w+)$/ ) {
        $method = $1;
    }
    elsif ( $action =~ /\/(\w+)$/ ) {
        $method = $1;
    }

    my $executed = sprintf( "%s->%s", $class, $method )
      if ( $class && $method );

    $c->response->headers->push_header( 'X-Catalyst-Executed' => $executed );
    return $c->SUPER::execute(@_);
}

1;
