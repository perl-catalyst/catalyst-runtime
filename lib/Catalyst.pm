package Catalyst;

use strict;
use base 'Class::Data::Inheritable';
use UNIVERSAL::require;
use Catalyst::Log;

__PACKAGE__->mk_classdata($_) for qw/_config log/;

our $VERSION = '4.01';
our @ISA;

=head1 NAME

Catalyst - The Elegant MVC Web Application Framework

=head1 SYNOPSIS

    # use the helper to start a new application
    catalyst MyApp
    cd MyApp

    # add models, views, controllers
    bin/create model Something
    bin/create view Stuff
    bin/create controller Yada

    # built in testserver
    bin/server

    # command line interface
    bin/test /yada


    See also L<Catalyst::Manual::Intro>


    use Catalyst;

    use Catalyst qw/My::Module My::OtherModule/;

    use Catalyst '-Debug';

    use Catalyst qw/-Debug -Engine=CGI/;

    __PACKAGE__->action( '!default' => sub { $_[1]->res->output('Hello') } );

    __PACKAGE__->action(
        'index.html' => sub {
            my ( $self, $c ) = @_;
            $c->res->output('Hello');
            $c->forward('_foo');
        }
    );

    __PACKAGE__->action(
        '/^product[_]*(\d*).html$/' => sub {
            my ( $self, $c ) = @_;
            $c->stash->{template} = 'product.tt';
            $c->stash->{product} = $c->req->snippets->[0];
        }
    );

=head1 DESCRIPTION

Catalyst is based upon L<Maypole>, which you should consider for smaller
projects.

The key concept of Catalyst is DRY (Don't Repeat Yourself).

See L<Catalyst::Manual> for more documentation.

Omit the Catalyst::Plugin:: prefix from plugins.
So Catalyst::Plugin::My::Module becomes My::Module.

    use Catalyst 'My::Module';

You can also set special flags like -Debug and -Engine.

    use Catalyst qw/-Debug My::Module/;

The position of plugins and flags in the chain is important,
because they are loaded in the same order they appear.

=head2 -Debug

    use Catalyst '-Debug';

is equivalent to

    use Catalyst;
    sub debug { 1 }

=head2 -Engine

Force Catalyst to use a specific engine.
Omit the Catalyst::Engine:: prefix.

    use Catalyst '-Engine=CGI';

=head2 METHODS

=head3 debug

Overload to enable debug messages.

=cut

sub debug { 0 }

=head3 config

Returns a hashref containing your applications settings.

=cut

sub config {
    my $self = shift;
    $self->_config( {} ) unless $self->_config;
    if ( $_[0] ) {
        my $config = $_[1] ? {@_} : $_[0];
        while ( my ( $key, $val ) = each %$config ) {
            $self->_config->{$key} = $val;
        }
    }
    return $self->_config;
}

sub import {
    my ( $self, @options ) = @_;
    my $caller = caller(0);

    # Class
    {
        no strict 'refs';
        *{"$caller\::handler"} =
          sub { Catalyst::Engine::handler( $caller, @_ ) };
        push @{"$caller\::ISA"}, $self;
    }
    $self->log( Catalyst::Log->new );

    # Options
    my $engine =
      $ENV{MOD_PERL} ? 'Catalyst::Engine::Apache' : 'Catalyst::Engine::CGI';
    foreach (@options) {
        if (/^\-Debug$/) {
            no warnings;
            no strict 'refs';
            *{"$self\::debug"} = sub { 1 };
            $caller->log->debug('Debug messages enabled');
        }
        elsif (/^-Engine=(.*)$/) { $engine = "Catalyst::Engine::$1" }
        elsif (/^-.*$/) { $caller->log->error(qq/Unknown flag "$_"/) }
        else {
            my $plugin = "Catalyst::Plugin::$_";

            # Plugin caller should be our application class
            eval "package $caller; require $plugin";
            if ($@) {
                $caller->log->error(qq/Couldn't load plugin "$plugin", "$@"/);
            }
            else {
                $caller->log->debug(qq/Loaded plugin "$plugin"/)
                  if $caller->debug;
                unshift @ISA, $plugin;
            }
        }
    }

    # Engine
    $engine = "Catalyst::Engine::$ENV{CATALYST_ENGINE}"
      if $ENV{CATALYST_ENGINE};
    $engine->require;
    die qq/Couldn't load engine "$engine", "$@"/ if $@;
    push @ISA, $engine;
    $caller->log->debug(qq/Loaded engine "$engine"/) if $caller->debug;
}

=head1 SEE ALSO

L<Catalyst::Manual>, L<Catalyst::Test>, L<Catalyst::Request>,
L<Catalyst::Response>, L<Catalyst::Engine>

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 THANK YOU

Danijel Milicevic, David Naughton, Gary Ashton Jones, Jesse Sheidlower,
Marcus Ramberg and all the others who've helped.

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
