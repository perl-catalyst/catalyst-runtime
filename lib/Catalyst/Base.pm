package Catalyst::Base;

use strict;
use base qw/Catalyst::AttrContainer Class::Accessor::Fast/;

use Catalyst::Exception;
use Catalyst::Utils;
use Class::Inspector;
use NEXT;

__PACKAGE__->mk_classdata($_) for qw/_config _dispatch_steps/;

__PACKAGE__->_dispatch_steps( [qw/_BEGIN _AUTO _ACTION/] );

sub _DISPATCH : Private {
    my ( $self, $c ) = @_;

    foreach my $disp ( @{ $self->_dispatch_steps } ) {
        last unless $c->forward($disp);
    }

    $c->forward('_END');
}

sub _BEGIN : Private {
    my ( $self, $c ) = @_;
    my $begin = ($c->get_actions( 'begin', $c->namespace))[-1];
    return 1 unless $begin;
    $begin->execute($c);
    return !@{ $c->error };
}

sub _AUTO : Private {
    my ( $self, $c ) = @_;
    my @auto = $c->get_actions('auto', $c->namespace);
    foreach my $auto (@auto) {
        $auto->execute($c);
        return 0 unless $c->state;
    }
    return 1;
}

sub _ACTION : Private {
    my ( $self, $c ) = @_;
    $c->action->execute($c);
    return !@{ $c->error };
}

sub _END : Private {
    my ( $self, $c ) = @_;
    my $end = ($c->get_actions( 'end', $c->namespace))[-1];
    return 1 unless $end;
    $end->execute($c);
    return !@{ $c->error };
}

sub action_namespace {
    my ( $self, $c ) = @_;
    return
        Catalyst::Utils::class2prefix(
            ref $self, $c->config->{case_sensitive} ) || '';
}

sub register_actions {
    my ( $self, $c ) = @_;
    my $class = ref $self || $self;
    my $namespace = $self->action_namespace( $c );
    my %methods;
    $methods{$self->can($_)} = $_ for @{Class::Inspector->methods($class)||[]};
    foreach my $cache (@{$self->_action_cache}) {
        my $code = $cache->[0];
        my $method = $methods{$code};
        next unless $method;
        my $attrs = $self->_parse_attrs(@{$cache->[1]});
        if ($attrs->{Private} && ( keys %$attrs > 1 ) ) {
            $c->log->debug( 'Bad action definition "'
                  . join( ' ', @{$cache->[1]} )
                  . qq/" for "$class->$method"/ )
              if $c->debug;
            next;
        }
        my $reverse = $namespace ? "$namespace/$method" : $method;
        my $action = Catalyst::Action->new(
            {
                name       => $method,
                code       => $code,
                reverse    => $reverse,
                namespace  => $namespace,
                class      => $class,
                attributes => $attrs,
            }
        );
        $c->dispatcher->register($c, $action);
    }
}

sub _parse_attrs {
    my ( $self, @attrs ) = @_;
    my %attributes;
    foreach my $attr (@attrs) {

        # Parse out :Foo(bar) into Foo => bar etc (and arrayify)

        if ( my ( $key, $value ) = ( $attr =~ /^(.*?)(?:\(\s*(.+)\s*\))?$/ ) ) {

            if ( defined $value ) {
                ( $value =~ s/^'(.*)'$/$1/ ) || ( $value =~ s/^"(.*)"/$1/ );
            }
            push( @{ $attributes{$key} }, $value );
        }
    }
    return \%attributes;
}


=head1 NAME

Catalyst::Base - Catalyst Universal Base Class

=head1 SYNOPSIS

    # lib/MyApp/Model/Something.pm
    package MyApp::Model::Something;

    use base 'Catalyst::Base';

    __PACKAGE__->config( foo => 'bar' );

    sub test {
        my $self = shift;
        return $self->{foo};
    }

    sub forward_to_me {
        my ( $self, $c ) = @_;
        $c->response->output( $self->{foo} );
    }
    
    1;

    # Methods can be a request step
    $c->forward(qw/MyApp::Model::Something forward_to_me/);

    # Or just methods
    print $c->comp('MyApp::Model::Something')->test;

    print $c->comp('MyApp::Model::Something')->{foo};

=head1 DESCRIPTION

This is the universal base class for Catalyst components
(Model/View/Controller).

It provides you with a generic new() for instantiation through Catalyst's
component loader with config() support and a process() method placeholder.

=head1 METHODS

=over 4

=item new($c)

=cut

sub new {
    my ( $self, $c ) = @_;

    # Temporary fix, some components does not pass context to constructor
    my $arguments = ( ref( $_[-1] ) eq 'HASH' ) ? $_[-1] : {};

    return $self->NEXT::new( { %{ $self->config }, %{$arguments} } );
}

# remember to leave blank lines between the consecutive =item's
# otherwise the pod tools don't recognize the subsequent =items

=item $c->config

=item $c->config($hashref)

=item $c->config($key, $value, ...)

=cut

sub config {
    my $self = shift;
    $self->_config( {} ) unless $self->_config;
    if (@_) {
        my $config = @_ > 1 ? {@_} : $_[0];
        while ( my ( $key, $val ) = each %$config ) {
            $self->_config->{$key} = $val;
        }
    }
    return $self->_config;
}

=item $c->process()

=cut

sub process {

    Catalyst::Exception->throw( message => ( ref $_[0] || $_[0] )
          . " did not override Catalyst::Base::process" );
}

=back

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Marcus Ramberg, C<mramberg@cpan.org>
Matt S Trout, C<mst@shadowcatsystems.co.uk>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
