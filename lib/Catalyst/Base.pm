package Catalyst::Base;

use strict;
use base qw/Catalyst::Component Catalyst::AttrContainer Class::Accessor::Fast/;

use Catalyst::Exception;
use Catalyst::Utils;
use Class::Inspector;
use NEXT;

__PACKAGE__->mk_classdata($_) for qw/_dispatch_steps _action_class/;

__PACKAGE__->_dispatch_steps( [qw/_BEGIN _AUTO _ACTION/] );
__PACKAGE__->_action_class('Catalyst::Action');

sub _DISPATCH : Private {
    my ( $self, $c ) = @_;

    foreach my $disp ( @{ $self->_dispatch_steps } ) {
        last unless $c->forward($disp);
    }

    $c->forward('_END');
}

sub _BEGIN : Private {
    my ( $self, $c ) = @_;
    my $begin = ( $c->get_actions( 'begin', $c->namespace ) )[-1];
    return 1 unless $begin;
    $begin->execute($c);
    return !@{ $c->error };
}

sub _AUTO : Private {
    my ( $self, $c ) = @_;
    my @auto = $c->get_actions( 'auto', $c->namespace );
    foreach my $auto (@auto) {
        $auto->execute($c);
        return 0 unless $c->state;
    }
    return 1;
}

sub _ACTION : Private {
    my ( $self, $c ) = @_;
    if (   ref $c->action
        && $c->action->can('execute')
        && $c->req->action )
    {
        $c->action->execute($c);
    }
    return !@{ $c->error };
}

sub _END : Private {
    my ( $self, $c ) = @_;
    my $end = ( $c->get_actions( 'end', $c->namespace ) )[-1];
    return 1 unless $end;
    $end->execute($c);
    return !@{ $c->error };
}

=head1 NAME

Catalyst::Base - Catalyst Base Class

=head1 SYNOPSIS

See L<Catalyst>

=head1 DESCRIPTION

Catalyst Base Class

=head1 METHODS

=head2 $self->action_namespace($c)

=cut

sub action_namespace {
    my ( $self, $c ) = @_;
    return $self->config->{namespace} if exists $self->config->{namespace};
    return Catalyst::Utils::class2prefix( ref($self) || $self,
        $c->config->{case_sensitive} )
      || '';
}

=head2 $self->path_prefix($c)

=cut

sub path_prefix { shift->action_namespace(@_); }

=head2 $self->register_actions($c)

=cut

sub register_actions {
    my ( $self, $c ) = @_;
    my $class = ref $self || $self;
    my $namespace = $self->action_namespace($c);
    my %methods;
    $methods{ $self->can($_) } = $_
      for @{ Class::Inspector->methods($class) || [] };

    # Advanced inheritance support for plugins and the like
    my @action_cache;
    {
        no strict 'refs';
        for my $isa ( @{"$class\::ISA"}, $class ) {
            push @action_cache, @{ $isa->_action_cache }
              if $isa->can('_action_cache');
        }
    }

    foreach my $cache (@action_cache) {
        my $code   = $cache->[0];
        my $method = $methods{$code};
        next unless $method;
        my $attrs = $self->_parse_attrs( $c, $method, @{ $cache->[1] } );
        if ( $attrs->{Private} && ( keys %$attrs > 1 ) ) {
            $c->log->debug( 'Bad action definition "'
                  . join( ' ', @{ $cache->[1] } )
                  . qq/" for "$class->$method"/ )
              if $c->debug;
            next;
        }
        my $reverse = $namespace ? "$namespace/$method" : $method;
        my $action = $self->_action_class->new(
            {
                name       => $method,
                code       => $code,
                reverse    => $reverse,
                namespace  => $namespace,
                class      => $class,
                attributes => $attrs,
            }
        );
        $c->dispatcher->register( $c, $action );
    }
}

sub _parse_attrs {
    my ( $self, $c, $name, @attrs ) = @_;
    my %attributes;
    foreach my $attr (@attrs) {

        # Parse out :Foo(bar) into Foo => bar etc (and arrayify)

        if ( my ( $key, $value ) = ( $attr =~ /^(.*?)(?:\(\s*(.+?)\s*\))?$/ ) )
        {

            if ( defined $value ) {
                ( $value =~ s/^'(.*)'$/$1/ ) || ( $value =~ s/^"(.*)"/$1/ );
            }
            my $meth = "_parse_${key}_attr";
            if ( $self->can($meth) ) {
                ( $key, $value ) = $self->$meth( $c, $name, $value );
            }
            push( @{ $attributes{$key} }, $value );
        }
    }
    return \%attributes;
}

sub _parse_Global_attr {
    my ( $self, $c, $name, $value ) = @_;
    return $self->_parse_Path_attr( $c, $name, "/$name" );
}

sub _parse_Absolute_attr { shift->_parse_Global_attr(@_); }

sub _parse_Local_attr {
    my ( $self, $c, $name, $value ) = @_;
    return $self->_parse_Path_attr( $c, $name, $name );
}

sub _parse_Relative_attr { shift->_parse_Local_attr(@_); }

sub _parse_Path_attr {
    my ( $self, $c, $name, $value ) = @_;
    $value ||= '';
    if ( $value =~ m!^/! ) {
        return ( 'Path', $value );
    }
    elsif ( length $value ) {
        return ( 'Path', join( '/', $self->path_prefix($c), $value ) );
    }
    else {
        return ( 'Path', $self->path_prefix($c) );
    }
}

sub _parse_Regex_attr {
    my ( $self, $c, $name, $value ) = @_;
    return ( 'Regex', $value );
}

sub _parse_Regexp_attr { shift->_parse_Regex_attr(@_); }

sub _parse_LocalRegex_attr {
    my ( $self, $c, $name, $value ) = @_;
    unless ( $value =~ s/^\^// ) { $value = "(?:.*?)$value"; }
    return ( 'Regex', '^' . $self->path_prefix($c) . "/${value}" );
}

sub _parse_LocalRegexp_attr { shift->_parse_LocalRegex_attr(@_); }

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Controller>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Marcus Ramberg, C<mramberg@cpan.org>
Matt S Trout, C<mst@shadowcatsystems.co.uk>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
