package Catalyst;

use strict;
use base 'Catalyst::Base';
use UNIVERSAL::require;
use Catalyst::Log;
use Catalyst::Utils;
use Text::ASCIITable;
use Path::Class;
our $CATALYST_SCRIPT_GEN = 4;

__PACKAGE__->mk_classdata($_) for qw/dispatcher engine log/;

our $VERSION = '5.22';
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
        $c->forward('foo');
    }

    sub product : Regex('^product[_]*(\d*).html$') {
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

    if ( $ENV{MOD_PERL} ) {

        my ( $software, $version ) = $ENV{MOD_PERL} =~ /^(\S+)\/(\d+(?:[\.\_]\d+)+)/;

        $version =~ s/_//g;
        $version =~ s/(\.[^.]+)\./$1/g;

        if ( $software eq 'mod_perl') {

            if ( $version >= 1.99922 ) {

                $engine = 'Catalyst::Engine::Apache::MP20';

                if ( Apache2::Request->require ) {
                    $engine = 'Catalyst::Engine::Apache::MP20::Apreq';
                }
            }

            elsif ( $version >= 1.9901 ) {

                $engine = 'Catalyst::Engine::Apache::MP19';

                if ( Apache::Request->require ) {
                    $engine = 'Catalyst::Engine::Apache::MP19::Apreq';
                }
            }

            elsif ( $version >= 1.24 ) {

                $engine = 'Catalyst::Engine::Apache::MP13';

                if ( Apache::Request->require ) {
                    $engine = 'Catalyst::Engine::Apache::MP13::Apreq';
                }
            }

            else {
                die( qq/Unsupported mod_perl version: $ENV{MOD_PERL}/ );
            }
        }

        elsif ( $software eq 'Zeus-Perl' ) {
            $engine = 'Catalyst::Engine::Zeus';
        }

        else {
            die( qq/Unsupported mod_perl: $ENV{MOD_PERL}/ );
        }
    }

    $caller->log->info( "You are running an old helper script! "
          . "Please update your scripts by regenerating the "
          . "application and copying over the new scripts." )
      if ( $ENV{CATALYST_SCRIPT_GEN}
        && ( $ENV{CATALYST_SCRIPT_GEN} < $CATALYST_SCRIPT_GEN ) );

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

    # Dispatcher
    $dispatcher = "Catalyst::Dispatcher::$ENV{CATALYST_DISPATCHER}"
      if $ENV{CATALYST_DISPATCHER};
    my $appdis = $ENV{ uc($caller) . '_DISPATCHER' };
    $dispatcher = "Catalyst::Dispatcher::$appdis" if $appdis;

    $dispatcher->require;
    die qq/Couldn't load dispatcher "$dispatcher", "$@"/ if $@;
    {
        no strict 'refs';
        push @{"$caller\::ISA"}, $dispatcher;
    }
    $caller->dispatcher($dispatcher);
    $caller->log->debug(qq/Loaded dispatcher "$dispatcher"/) if $caller->debug;

    # Engine
    $engine = "Catalyst::Engine::$ENV{CATALYST_ENGINE}"
      if $ENV{CATALYST_ENGINE};
    my $appeng = $ENV{ uc($caller) . '_ENGINE' };
    $engine = "Catalyst::Engine::$appeng" if $appeng;

    $engine->require;
    die qq/Couldn't load engine "$engine", "$@"/ if $@;

    {
        no strict 'refs';
        push @{"$caller\::ISA"}, $engine;
    }

    $caller->engine($engine);
    $caller->log->debug(qq/Loaded engine "$engine"/) if $caller->debug;

    # Find home
    my $home = Catalyst::Utils::home($caller);

    if ( my $h = $ENV{CATALYST_HOME} ) {

        $home = $h if -d $h;

        unless ( -e _ ) {
            $caller->log->warn(qq/CATALYST_HOME does not exist "$h"/);
        }

        unless ( -e _ && -d _ ) {
            $caller->log->warn(qq/CATALYST_HOME is not a directory "$h"/);
        }
    }

    if ( my $h = $ENV{ uc($caller) . '_HOME' } ) {

        $home = $h if -d $h;

        unless ( -e _ ) {
            my $e = uc($caller) . '_HOME';
            $caller->log->warn(qq/$e does not exist "$h"/)
        }

        unless ( -e _ && -d _ ) {
            my $e = uc($caller) . '_HOME';
            $caller->log->warn(qq/$e is not a directory "$h"/);
        }
    }

    if ( $caller->debug ) {
        $home
          ? ( -d $home )
          ? $caller->log->debug(qq/Found home "$home"/)
          : $caller->log->debug(qq/Home "$home" doesn't exist/)
          : $caller->log->debug(q/Couldn't find home/);
    }
    $caller->config->{home} = $home || '';
    $caller->config->{root} = defined $home ? dir($home)->subdir('root') : '';
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

=item $c->plugin( $name, $class, @args )

Instant plugins for Catalyst.
Classdata accessor/mutator will be created, class loaded and instantiated.

    MyApp->plugin( 'prototype', 'HTML::Prototype' );

    $c->prototype->define_javascript_functions;

=cut

sub plugin {
    my ( $class, $name, $plugin, @args ) = @_;
    $plugin->require;
    my $error = $UNIVERSAL::require::ERROR;
    die qq/Couldn't load instant plugin "$plugin", "$error"/ if $error;
    eval { $plugin->import };
    $class->mk_classdata($name);
    my $obj;
    eval { $obj = $plugin->new(@args) };
    die qq/Couldn't instantiate instant plugin "$plugin", "$@"/ if $@;
    $class->$name($obj);
    $class->log->debug(qq/Initialized instant plugin "$plugin" as "$name"/)
      if $class->debug;
}

=back

=head1 LIMITATIONS

mod_perl2 support is considered experimental and may contain bugs.

=head1 SUPPORT

IRC:

    Join #catalyst on irc.perl.org.

Mailing-Lists:

    http://lists.rawmode.org/mailman/listinfo/catalyst
    http://lists.rawmode.org/mailman/listinfo/catalyst-dev

Web:

    http://catalyst.perl.org

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

Andy Grundman, Andrew Ford, Andrew Ruthven, Autrijus Tang, Christian Hansen,
Christopher Hicks, Dan Sully, Danijel Milicevic, David Naughton,
Gary Ashton Jones, Geoff Richards, Jesse Sheidlower, Jody Belka,
Johan Lindstrom, Juan Camacho, Leon Brocard, Marcus Ramberg,
Tatsuhiko Miyagawa and all the others who've helped.

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
