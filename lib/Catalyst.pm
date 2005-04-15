package Catalyst;

use strict;
use base 'Catalyst::Base';
use UNIVERSAL::require;
use Catalyst::Log;
use Catalyst::Helper;
use Text::ASCIITable;

__PACKAGE__->mk_classdata($_) for qw/dispatcher engine log/;

our $VERSION = '5.00';
our @ISA;

=head1 NAME

Catalyst - The Elegant MVC Web Application Framework

=head1 SYNOPSIS

    # use the helper to start a new application
    catalyst.pl MyApp
    cd MyApp

    # add models, views, controllers
    script/create.pl model Something
    script/create.pl view Stuff
    script/create.pl controller Yada

    # built in testserver
    script/server.pl

    # command line interface
    script/test.pl /yada


    use Catalyst;

    use Catalyst qw/My::Module My::OtherModule/;

    use Catalyst '-Debug';

    use Catalyst qw/-Debug -Engine=CGI/;

    sub default : Private { $_[1]->res->output('Hello') } );

    sub index : Path('/index.html') {
        my ( $self, $c ) = @_;
        $c->res->output('Hello');
        $c->forward('_foo');
    }

    sub product : Regex('/^product[_]*(\d*).html$/') {
        my ( $self, $c ) = @_;
        $c->stash->{template} = 'product.tt';
        $c->stash->{product} = $c->req->snippets->[0];
    }

See also L<Catalyst::Manual::Intro>

=head1 DESCRIPTION

Catalyst is based upon L<Maypole>, which you should consider for smaller
projects.

The key concept of Catalyst is DRY (Don't Repeat Yourself).

See L<Catalyst::Manual> for more documentation.

Catalyst plugins can be loaded by naming them as arguments to the "use Catalyst" statement.
Omit the C<Catalyst::Plugin::> prefix from the plugin name,
so C<Catalyst::Plugin::My::Module> becomes C<My::Module>.

    use Catalyst 'My::Module';

Special flags like -Debug and -Engine can also be specifed as arguments when
Catalyst is loaded:

    use Catalyst qw/-Debug My::Module/;

The position of plugins and flags in the chain is important, because they are
loaded in exactly the order that they appear.

The following flags are supported:

=over 4

=item -Debug

enables debug output, i.e.:

    use Catalyst '-Debug';

this is equivalent to:

    use Catalyst;
    sub debug { 1 }

=item -Engine

Force Catalyst to use a specific engine.
Omit the C<Catalyst::Engine::> prefix of the engine name, i.e.:

    use Catalyst '-Engine=CGI';

=back

=head1 METHODS

=over 4

=item debug

Overload to enable debug messages.

=cut

sub debug { 0 }

=item config

Returns a hashref containing your applications settings.

=cut

sub import {
    my ( $self, @options ) = @_;
    my $caller = caller(0);

    # Prepare inheritance
    unless ( $caller->isa($self) ) {
        no strict 'refs';
        push @{"$caller\::ISA"}, $self;
    }

    if ( $caller->engine ) {
        return;    # Catalyst is already initialized
    }

    unless ( $caller->log ) {
        $caller->log( Catalyst::Log->new );
    }

    # Debug?
    if ( $ENV{CATALYST_DEBUG} || $ENV{ uc($caller) . '_DEBUG' } ) {
        no strict 'refs';
        *{"$caller\::debug"} = sub { 1 };
        $caller->log->debug('Debug messages enabled');
    }

    my $engine     = 'Catalyst::Engine::CGI';
    my $dispatcher = 'Catalyst::Dispatcher';

    # Detect mod_perl
    if ( $ENV{MOD_PERL} ) {

        require mod_perl;

        if ( $mod_perl::VERSION >= 1.99 ) {
            $engine = 'Catalyst::Engine::Apache::MP19';
        }
        else {
            $engine = 'Catalyst::Engine::Apache::MP13';
        }
    }

    $caller->log->info("You are running an old helper script! ".
             "Please update your scripts by regenerating the ".
             "application and copying over the new scripts.")
        if ( $ENV{CATALYST_SCRIPT_GEN} && ( 
             $ENV{CATALYST_SCRIPT_GEN} < 
             $Catalyst::Helper::CATALYST_SCRIPT_GEN )) ;
    # Process options
    my @plugins;
    foreach (@options) {

        if (/^\-Debug$/) {
            next if $caller->debug;
            no strict 'refs';
            *{"$caller\::debug"} = sub { 1 };
            $caller->log->debug('Debug messages enabled');
        }

        elsif (/^-Dispatcher=(.*)$/) {
            $dispatcher = "Catalyst::Dispatcher::$1";
        }

        elsif (/^-Engine=(.*)$/) { $engine = "Catalyst::Engine::$1" }
        elsif (/^-.*$/) { $caller->log->error(qq/Unknown flag "$_"/) }

        else {
            my $plugin = "Catalyst::Plugin::$_";

            $plugin->require;

            if ($@) { die qq/Couldn't load plugin "$plugin", "$@"/ }
            else {
                push @plugins, $plugin;
                no strict 'refs';
                push @{"$caller\::ISA"}, $plugin;
            }
        }

    }

    # Plugin table
    my $t = Text::ASCIITable->new( { hide_HeadRow => 1, hide_HeadLine => 1 } );
    $t->setCols('Class');
    $t->setColWidth( 'Class', 75, 1 );
    $t->addRow($_) for @plugins;
    $caller->log->debug( 'Loaded plugins', $t->draw )
      if ( @plugins && $caller->debug );

    # Engine
    $engine = "Catalyst::Engine::$ENV{CATALYST_ENGINE}"
      if $ENV{CATALYST_ENGINE};

    $engine->require;
    die qq/Couldn't load engine "$engine", "$@"/ if $@;
    {
        no strict 'refs';
        push @{"$caller\::ISA"}, $engine;
    }
    $caller->engine($engine);
    $caller->log->debug(qq/Loaded engine "$engine"/) if $caller->debug;

    # Dispatcher
    $dispatcher = "Catalyst::Dispatcher::$ENV{CATALYST_DISPATCHER}"
      if $ENV{CATALYST_DISPATCHER};

    $dispatcher->require;
    die qq/Couldn't load dispatcher "$dispatcher", "$@"/ if $@;
    {
        no strict 'refs';
        push @{"$caller\::ISA"}, $dispatcher;
    }
    $caller->dispatcher($dispatcher);
    $caller->log->debug(qq/Loaded dispatcher "$dispatcher"/) if $caller->debug;

}

=item $c->engine

Contains the engine class.

=item $c->log

Contains the logging object.  Unless it is already set Catalyst sets this up with a
C<Catalyst::Log> object.  To use your own log class:

    $c->log( MyLogger->new );
    $c->log->info("now logging with my own logger!");

Your log class should implement the methods described in the C<Catalyst::Log>
man page.


=back

=head1 LIMITATIONS

FCGI and mod_perl2 support are considered experimental and may contain bugs.

You may encounter problems accessing the built in test server on public ip
addresses on the internet, thats because of a bug in HTTP::Daemon.

=head1 SUPPORT

IRC:

    Join #catalyst on irc.perl.org.

Mailing-Lists:

    http://lists.rawmode.org/mailman/listinfo/catalyst
    http://lists.rawmode.org/mailman/listinfo/catalyst-dev

=head1 SEE ALSO

=over 4

=item L<Catalyst::Manual> - The Catalyst Manual

=item L<Catalyst::Engine> - Core Engine

=item L<Catalyst::Log> - The Log Class.

=item L<Catalyst::Request> - The Request Object

=item L<Catalyst::Response> - The Response Object

=item L<Catalyst::Test> - The test suite.

=back

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 THANK YOU

Andy Grundman, Andrew Ford, Andrew Ruthven, Christian Hansen,
Christopher Hicks, Dan Sully, Danijel Milicevic, David Naughton,
Gary Ashton Jones, Jesse Sheidlower, Johan Lindstrom, Marcus Ramberg,
Tatsuhiko Miyagawa and all the others who've helped.

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
