package TestApp::Controller::Moose;

use Moose;

BEGIN { extends qw/Catalyst::Controller/; }

has attribute => ( # Test defaults work
    is      => 'ro',
    default => 42,
);

has other_attribute => ( # Test BUILD method is called
    is => 'rw'
);

has punctuation => ( # Test BUILD method gets merged config
    is => 'rw'
);

has space => ( # Test that attribute slots get filled from merged config
    is => 'ro'
);

no Moose;

__PACKAGE__->config(the_punctuation => ':');
__PACKAGE__->config(space => ' '); # i am pbp, icm5ukp

sub BUILD {
    my ($self, $config) = @_;
    # Note, not an example of something you would ever
    $self->other_attribute('the meaning of life');
    $self->punctuation( $config->{the_punctuation} );
}

sub the_answer : Local {
    my ($self, $c) = @_;
    $c->response->body($self->other_attribute . $self->punctuation . $self->space . $self->attribute);
}

1;
