{
    package NewTestPlugin;
    use strict;
    use warnings;
    sub new { 
        my $class = shift;
        return bless $_[0], $class; 
    }
}

{
    package TestAppPluginWithNewMethod;
    use Test::Exception;
    use Catalyst qw/+NewTestPlugin/;

    sub foo : Local {
        my ($self, $c) = @_;
        $c->res->body('foo');
    }

    use Moose; # Just testing method modifiers still work.
    __PACKAGE__->setup;
    our $MODIFIER_FIRED = 0;

    lives_ok {
        before 'dispatch' => sub { $MODIFIER_FIRED = 1 }
    } 'Can apply method modifier';
    no Moose;
}
