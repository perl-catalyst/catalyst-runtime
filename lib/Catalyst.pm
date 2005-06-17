package Catalyst;

use strict;
use base 'Catalyst::Base';
use UNIVERSAL::require;
use Catalyst::Exception;
use Catalyst::Log;
use Catalyst::Utils;
use Text::ASCIITable;
use Path::Class;
our $CATALYST_SCRIPT_GEN = 4;

__PACKAGE__->mk_classdata($_) for qw/dispatcher engine log/;

our $VERSION = '5.24';
our @ISA;

=head1 NAME

Catalyst - The Elegant MVC Web Application Framework

=head1 SYNOPSIS

    # use the helper to start a new application
    catalyst.pl MyApp
    cd MyApp

    # add models, views, controllers
    script/myapp_create.pl model Something
    script/myapp_create.pl view Stuff
    script/myapp_create.pl controller Yada

    # built in testserver
    script/myapp_server.pl

    # command line interface
    script/myapp_test.pl /yada


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
    my ( $class, @arguments ) = @_;
    my $caller = caller(0);

    # Prepare inheritance
    unless ( $caller->isa($class) ) {
        no strict 'refs';
        push @{"$caller\::ISA"}, $class;
    }

    if ( $caller->engine ) {
        $caller->log->warn( qq/Attempt to re-initialize "$caller"/ );
        return;
    }

    # Process options
    my $flags = { };

    foreach (@arguments) {

        if ( /^-Debug$/ ) {
            $flags->{log} = 1
        }
        elsif (/^-(\w+)=?(.*)$/) {
            $flags->{ lc $1 } = $2;
        }
        else {
            push @{ $flags->{plugins} }, $_;
        }
    }

    $caller->setup_log        ( delete $flags->{log}        );
    $caller->setup_plugins    ( delete $flags->{plugins}    );
    $caller->setup_dispatcher ( delete $flags->{dispatcher} );
    $caller->setup_engine     ( delete $flags->{engine}     );
    $caller->setup_home       ( delete $flags->{home}       );

    for my $flag ( sort keys %{ $flags } ) {

        if ( my $code = $caller->can( 'setup_' . $flag ) ) {
            &$code( $caller, delete $flags->{$flag} );
        }
        else {
            $caller->log->warn(qq/Unknown flag "$flag"/);
        }
    }

    $caller->log->warn( "You are running an old helper script! "
          . "Please update your scripts by regenerating the "
          . "application and copying over the new scripts." )
      if ( $ENV{CATALYST_SCRIPT_GEN}
        && ( $ENV{CATALYST_SCRIPT_GEN} < $CATALYST_SCRIPT_GEN ) );


    if ( $caller->debug ) {

        my @plugins = ();

        {
            no strict 'refs';
            @plugins = grep { /^Catalyst::Plugin/ } @{"$caller\::ISA"};
        }

        if ( @plugins ) {
            my $t = Text::ASCIITable->new;
            $t->setOptions( 'hide_HeadRow',  1 );
            $t->setOptions( 'hide_HeadLine', 1 );
            $t->setCols('Class');
            $t->setColWidth( 'Class', 75, 1 );
            $t->addRow($_) for @plugins;
            $caller->log->debug( 'Loaded plugins', $t->draw );
        }

        my $dispatcher = $caller->dispatcher;
        my $engine     = $caller->engine;
        my $home       = $caller->config->{home};

        $caller->log->debug(qq/Loaded dispatcher "$dispatcher"/);
        $caller->log->debug(qq/Loaded engine "$engine"/);

        $home
          ? ( -d $home )
          ? $caller->log->debug(qq/Found home "$home"/)
          : $caller->log->debug(qq/Home "$home" doesn't exist/)
          : $caller->log->debug(q/Couldn't find home/);
    }
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

    if ( my $error = $UNIVERSAL::require::ERROR ) {
        Catalyst::Exception->throw(
            message => qq/Couldn't load instant plugin "$plugin", "$error"/
        );
    }

    eval { $plugin->import };
    $class->mk_classdata($name);
    my $obj;
    eval { $obj = $plugin->new(@args) };

    if ( $@ ) {
        Catalyst::Exception->throw(
            message => qq/Couldn't instantiate instant plugin "$plugin", "$@"/
        );
    }

    $class->$name($obj);
    $class->log->debug(qq/Initialized instant plugin "$plugin" as "$name"/)
      if $class->debug;
}

=item $c->setup_dispatcher

=cut

sub setup_dispatcher {
    my ( $class, $dispatcher ) = @_;

    if ( $dispatcher ) {
        $dispatcher = 'Catalyst::Dispatcher::' . $dispatcher;
    }

    if ( $ENV{CATALYST_DISPATCHER} ) {
        $dispatcher = 'Catalyst::Dispatcher::' . $ENV{CATALYST_DISPATCHER};
    }

    if ( $ENV{ uc($class) . '_DISPATCHER' } ) {
        $dispatcher = 'Catalyst::Dispatcher::' . $ENV{ uc($class) . '_DISPATCHER' };
    }

    unless ( $dispatcher ) {
        $dispatcher = 'Catalyst::Dispatcher';
    }

    $dispatcher->require;

    if ( $@ ) {
        Catalyst::Exception->throw(
            message => qq/Couldn't load dispatcher "$dispatcher", "$@"/
        );
    }

    {
        no strict 'refs';
        push @{"$class\::ISA"}, $dispatcher;
    }

    $class->dispatcher($dispatcher);
}

=item $c->setup_engine

=cut

sub setup_engine {
    my ( $class, $engine ) = @_;

    if ( $engine ) {
        $engine = 'Catalyst::Engine::' . $engine;
    }

    if ( $ENV{CATALYST_ENGINE} ) {
        $engine = 'Catalyst::Engine::' . $ENV{CATALYST_ENGINE};
    }

    if ( $ENV{ uc($class) . '_ENGINE' } ) {
        $engine = 'Catalyst::Engine::' . $ENV{ uc($class) . '_ENGINE' };
    }

    if ( ! $engine && $ENV{MOD_PERL} ) {

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
                Catalyst::Exception->throw(
                    message => qq/Unsupported mod_perl version: $ENV{MOD_PERL}/
                );
            }
        }

        elsif ( $software eq 'Zeus-Perl' ) {
            $engine = 'Catalyst::Engine::Zeus';
        }

        else {
            Catalyst::Exception->throw(
                message => qq/Unsupported mod_perl: $ENV{MOD_PERL}/
            );
        }
    }

    unless ( $engine ) {
        $engine = 'Catalyst::Engine::CGI';
    }

    $engine->require;

    if ( $@ ) {
        Catalyst::Exception->throw(
            message => qq/Couldn't load engine "$engine", "$@"/
        );
    }

    {
        no strict 'refs';
        push @{"$class\::ISA"}, $engine;
    }

    $class->engine($engine);
}

=item $c->setup_home

=cut

sub setup_home {
    my ( $class, $home ) = @_;

    if ( $ENV{CATALYST_HOME} ) {
        $home = $ENV{CATALYST_HOME};
    }

    if ( $ENV{ uc($class) . '_HOME' } ) {
        $home = $ENV{ uc($class) . '_HOME' };
    }

    unless ( $home ) {
        $home = Catalyst::Utils::home($class);
    }

    if ( $home ) {
        $class->config->{home} = $home;
        $class->config->{root} = dir($home)->subdir('root');
    }
}

=item $c->setup_log

=cut

sub setup_log {
    my ( $class, $debug ) = @_;

    unless ( $class->log ) {
        $class->log( Catalyst::Log->new );
    }

    if ( $ENV{CATALYST_DEBUG} || $ENV{ uc($class) . '_DEBUG' } || $debug ) {
        no strict 'refs';
        *{"$class\::debug"} = sub { 1 };
        $class->log->debug('Debug messages enabled');
    }
}

=item $c->setup_plugins

=cut

sub setup_plugins {
    my ( $class, $plugins ) = @_;

    for my $plugin ( @$plugins ) {

        $plugin = "Catalyst::Plugin::$plugin";

        $plugin->require;

        if ( $@ ) {
            Catalyst::Exception->throw(
                message => qq/Couldn't load plugin "$plugin", "$@"/
            );
        }

        {
            no strict 'refs';
            push @{"$class\::ISA"}, $plugin;
        }
    }
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
