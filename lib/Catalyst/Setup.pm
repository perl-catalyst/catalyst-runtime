package Catalyst::Setup;

use strict;
use Catalyst::Exception;
use Catalyst::Log;
use Catalyst::Utils;
use Path::Class;
use Text::ASCIITable;

require Module::Pluggable::Fast;

=head1 NAME

Catalyst::Setup - The Catalyst Setup class

=head1 SYNOPSIS

See L<Catalyst>.

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item $c->setup

Setup.

    $c->setup;

=cut

sub setup {
    my ( $class, @arguments ) = @_;

    unless ( $class->isa('Catalyst') ) {

        Catalyst::Exception->throw(
            message => qq/'$class' does not inherit from Catalyst/
        );
    }
    
    if ( $class->arguments ) {
        @arguments = ( @arguments, @{ $class->arguments } );
    }

    # Process options
    my $flags = { };

    foreach (@arguments) {

        if ( /^-Debug$/ ) {
            $flags->{log} = ( $flags->{log} ) ? 'debug,' . $flags->{log} : 'debug';
        }
        elsif (/^-(\w+)=?(.*)$/) {
            $flags->{ lc $1 } = $2;
        }
        else {
            push @{ $flags->{plugins} }, $_;
        }
    }

    $class->setup_log        ( delete $flags->{log}        );
    $class->setup_plugins    ( delete $flags->{plugins}    );
    $class->setup_dispatcher ( delete $flags->{dispatcher} );
    $class->setup_engine     ( delete $flags->{engine}     );
    $class->setup_home       ( delete $flags->{home}       );

    for my $flag ( sort keys %{ $flags } ) {

        if ( my $code = $class->can( 'setup_' . $flag ) ) {
            &$code( $class, delete $flags->{$flag} );
        }
        else {
            $class->log->warn(qq/Unknown flag "$flag"/);
        }
    }

    $class->log->warn( "You are running an old helper script! "
          . "Please update your scripts by regenerating the "
          . "application and copying over the new scripts." )
      if ( $ENV{CATALYST_SCRIPT_GEN}
        && ( $ENV{CATALYST_SCRIPT_GEN} < $Catalyst::CATALYST_SCRIPT_GEN ) );


    if ( $class->debug ) {

        my @plugins = ();

        {
            no strict 'refs';
            @plugins = grep { /^Catalyst::Plugin/ } @{"$class\::ISA"};
        }

        if ( @plugins ) {
            my $t = Text::ASCIITable->new;
            $t->setOptions( 'hide_HeadRow',  1 );
            $t->setOptions( 'hide_HeadLine', 1 );
            $t->setCols('Class');
            $t->setColWidth( 'Class', 75, 1 );
            $t->addRow($_) for @plugins;
            $class->log->debug( "Loaded plugins:\n" . $t->draw );
        }

        my $dispatcher = $class->dispatcher;
        my $engine     = $class->engine;
        my $home       = $class->config->{home};

        $class->log->debug(qq/Loaded dispatcher "$dispatcher"/);
        $class->log->debug(qq/Loaded engine "$engine"/);

        $home
          ? ( -d $home )
          ? $class->log->debug(qq/Found home "$home"/)
          : $class->log->debug(qq/Home "$home" doesn't exist/)
          : $class->log->debug(q/Couldn't find home/);
    }

    # Call plugins setup
    $class->NEXT::setup;

    # Initialize our data structure
    $class->components( {} );

    $class->setup_components;

    if ( $class->debug ) {
        my $t = Text::ASCIITable->new;
        $t->setOptions( 'hide_HeadRow',  1 );
        $t->setOptions( 'hide_HeadLine', 1 );
        $t->setCols('Class');
        $t->setColWidth( 'Class', 75, 1 );
        $t->addRow($_) for sort keys %{ $class->components };
        $class->log->debug( "Loaded components:\n" . $t->draw )
          if ( @{ $t->{tbl_rows} } );
    }

    # Add our self to components, since we are also a component
    $class->components->{$class} = $class;

    $class->setup_actions;

    if ( $class->debug ) {
        my $name = $class->config->{name} || 'Application';
        $class->log->info("$name powered by Catalyst $Catalyst::VERSION");
    }
}

=item $c->setup_components

Setup components.

=cut

sub setup_components {
    my $class = shift;

    my $callback = sub {
        my ( $component, $context ) = @_;

        unless ( $component->isa('Catalyst::Base') ) {
            return $component;
        }

        my $suffix = Catalyst::Utils::class2classsuffix($component);
        my $config = $class->config->{$suffix} || {};

        my $instance;

        eval { $instance = $component->new( $context, $config ); };

        if ( my $error = $@ ) {

            chomp $error;

            Catalyst::Exception->throw( 
                message => qq/Couldn't instantiate component "$component", "$error"/
            );
        }

        return $instance;
    };

    eval {
        Module::Pluggable::Fast->import(
            name   => '_components',
            search => [
                "$class\::Controller", "$class\::C",
                "$class\::Model",      "$class\::M",
                "$class\::View",       "$class\::V"
            ],
            callback => $callback
        );
    };

    if ( my $error = $@ ) {

        chomp $error;

        Catalyst::Exception->throw( 
            message => qq/Couldn't load components "$error"/ 
        );
    }

    for my $component ( $class->_components($class) ) {
        $class->components->{ ref $component || $component } = $component;
    }
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
        $class->config->{home} ||= $home;
        $class->config->{root} ||= dir($home)->subdir('root');
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

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>
Christian Hansen, C<ch@ngmedia.com>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

1;
