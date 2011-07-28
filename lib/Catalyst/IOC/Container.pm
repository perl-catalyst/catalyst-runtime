package Catalyst::IOC::Container;
use Bread::Board;
use Moose;
use Config::Any;
use Data::Visitor::Callback;
use Catalyst::Utils ();
use Devel::InnerPackage ();
use Hash::Util qw/lock_hash/;
use MooseX::Types::LoadableClass qw/ LoadableClass /;
use Moose::Util;
use Catalyst::IOC::BlockInjection;
use Module::Pluggable::Object ();
use namespace::autoclean;

extends 'Bread::Board::Container';

has config_local_suffix => (
    is      => 'ro',
    isa     => 'Str',
    default => 'local',
);

has driver => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { +{} },
);

has file => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
);

has substitutions => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { +{} },
);

has application_name => (
    is      => 'ro',
    isa     => 'Str',
    default => 'MyApp',
);

has sub_container_class => (
    isa     => LoadableClass,
    is      => 'ro',
    coerce  => 1,
    default => 'Catalyst::IOC::SubContainer',
    handles => {
        new_sub_container => 'new',
    }
);

sub BUILD {
    my ( $self, $params ) = @_;

    $self->add_service(
        $self->${\"build_${_}_service"}
    ) for qw/
        substitutions
        file
        driver
        application_name
        prefix
        extensions
        path
        config
        raw_config
        global_files
        local_files
        global_config
        local_config
        config_local_suffix
        config_path
    /;

    $self->add_sub_container(
        $self->build_controller_subcontainer
    );

    # FIXME - the config should be merged at this point
    my $config        = $self->resolve( service => 'config' );
    my $default_view  = $params->{default_view}  || $config->{default_view};
    my $default_model = $params->{default_model} || $config->{default_model};

    $self->add_sub_container(
        $self->build_view_subcontainer(
            default_component => $default_view,
        )
    );

    $self->add_sub_container(
        $self->build_model_subcontainer(
            default_component => $default_model,
        )
    );
}

sub build_model_subcontainer {
    my $self = shift;

    return $self->new_sub_container( @_,
        name => 'model',
    );
}

sub build_view_subcontainer {
    my $self = shift;

    return $self->new_sub_container( @_,
        name => 'view',
    );
}

sub build_controller_subcontainer {
    my $self = shift;

    return $self->new_sub_container(
        name => 'controller',
    );
}

sub build_name_service {
    my $self = shift;

    return Bread::Board::Literal->new( name => 'application_name', value => $self->application_name );
}

sub build_driver_service {
    my $self = shift;

    return Bread::Board::Literal->new( name => 'driver', value => $self->driver );
}

sub build_file_service {
    my $self = shift;

    return Bread::Board::Literal->new( name => 'file', value => $self->file );
}

sub build_substitutions_service {
    my $self = shift;

    return Bread::Board::Literal->new( name => 'substitutions', value => $self->substitutions );
}

sub build_extensions_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'extensions',
        block => sub {
            return \@{Config::Any->extensions};
        },
    );
}

sub build_prefix_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'prefix',
        block => sub {
            return Catalyst::Utils::appprefix( shift->param('name') );
        },
        dependencies => [ depends_on('name') ],
    );
}

sub build_path_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'path',
        block => sub {
            my $s = shift;

            return Catalyst::Utils::env_value( $s->param('name'), 'CONFIG' )
            || $s->param('file')
            || $s->param('application_name')->path_to( $s->param('prefix') );
        },
        dependencies => [ depends_on('file'), depends_on('application_name'), depends_on('prefix') ],
    );
}

sub build_config_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'config',
        block => sub {
            my $s = shift;

            my $v = Data::Visitor::Callback->new(
                plain_value => sub {
                    return unless defined $_;
                    return $self->_config_substitutions( $s->param('application_name'), $s->param('substitutions'), $_ );
                }

            );
            $v->visit( $s->param('raw_config') );
        },
        dependencies => [ depends_on('application_name'), depends_on('raw_config'), depends_on('substitutions') ],
    );
}

sub build_raw_config_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'raw_config',
        block => sub {
            my $s = shift;

            my @global = @{$s->param('global_config')};
            my @locals = @{$s->param('local_config')};

            my $config = {};
            for my $cfg (@global, @locals) {
                for (keys %$cfg) {
                    $config = Catalyst::Utils::merge_hashes( $config, $cfg->{$_} );
                }
            }
            return $config;
        },
        dependencies => [ depends_on('global_config'), depends_on('local_config') ],
    );
}

sub build_global_files_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'global_files',
        block => sub {
            my $s = shift;

            my ( $path, $extension ) = @{$s->param('config_path')};

            my @extensions = @{$s->param('extensions')};

            my @files;
            if ( $extension ) {
                die "Unable to handle files with the extension '${extension}'" unless grep { $_ eq $extension } @extensions;
                push @files, $path;
            } else {
                @files = map { "$path.$_" } @extensions;
            }
            return \@files;
        },
        dependencies => [ depends_on('extensions'), depends_on('config_path') ],
    );
}

sub build_local_files_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'local_files',
        block => sub {
            my $s = shift;

            my ( $path, $extension ) = @{$s->param('config_path')};
            my $suffix = $s->param('config_local_suffix');

            my @extensions = @{$s->param('extensions')};

            my @files;
            if ( $extension ) {
                die "Unable to handle files with the extension '${extension}'" unless grep { $_ eq $extension } @extensions;
                $path =~ s{\.$extension}{_$suffix.$extension};
                push @files, $path;
            } else {
                @files = map { "${path}_${suffix}.$_" } @extensions;
            }
            return \@files;
        },
        dependencies => [ depends_on('extensions'), depends_on('config_path'), depends_on('config_local_suffix') ],
    );
}

sub build_global_config_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'global_config',
        block => sub {
            my $s = shift;

            return Config::Any->load_files({
                files       => $s->param('global_files'),
                filter      => \&_fix_syntax,
                use_ext     => 1,
                driver_args => $s->param('driver'),
            });
        },
        dependencies => [ depends_on('global_files') ],
    );
}

sub build_local_config_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'local_config',
        block => sub {
            my $s = shift;

            return Config::Any->load_files({
                files       => $s->param('local_files'),
                filter      => \&_fix_syntax,
                use_ext     => 1,
                driver_args => $s->param('driver'),
            });
        },
        dependencies => [ depends_on('local_files') ],
    );
}

sub build_config_path_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'config_path',
        block => sub {
            my $s = shift;

            my $path = $s->param('path');
            my $prefix = $s->param('prefix');

            my ( $extension ) = ( $path =~ m{\.(.{1,4})$} );

            if ( -d $path ) {
                $path =~ s{[\/\\]$}{};
                $path .= "/$prefix";
            }

            return [ $path, $extension ];
        },
        dependencies => [ depends_on('prefix'), depends_on('path') ],
    );
}

sub build_config_local_suffix_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'config_local_suffix',
        block => sub {
            my $s = shift;
            my $suffix = Catalyst::Utils::env_value( $s->param('application_name'), 'CONFIG_LOCAL_SUFFIX' ) || $self->config_local_suffix;

            return $suffix;
        },
        dependencies => [ depends_on('application_name') ],
    );
}

sub _fix_syntax {
    my $config     = shift;
    my @components = (
        map +{
            prefix => $_ eq 'Component' ? '' : $_ . '::',
            values => delete $config->{ lc $_ } || delete $config->{ $_ }
        },
        grep { ref $config->{ lc $_ } || ref $config->{ $_ } }
            qw( Component Model M View V Controller C Plugin )
    );

    foreach my $comp ( @components ) {
        my $prefix = $comp->{ prefix };
        foreach my $element ( keys %{ $comp->{ values } } ) {
            $config->{ "$prefix$element" } = $comp->{ values }->{ $element };
        }
    }
}

sub _config_substitutions {
    my ( $self, $name, $subs, $arg ) = @_;

    $subs->{ HOME } ||= sub { shift->path_to( '' ); };
    $subs->{ ENV } ||=
        sub {
            my ( $c, $v ) = @_;
            if (! defined($ENV{$v})) {
                Catalyst::Exception->throw( message =>
                    "Missing environment variable: $v" );
                return "";
            } else {
                return $ENV{ $v };
            }
        };
    $subs->{ path_to } ||= sub { shift->path_to( @_ ); };
    $subs->{ literal } ||= sub { return $_[ 1 ]; };
    my $subsre = join( '|', keys %$subs );

    $arg =~ s{__($subsre)(?:\((.+?)\))?__}{ $subs->{ $1 }->( $name, $2 ? split( /,/, $2 ) : () ) }eg;
    return $arg;
}

sub get_component_from_sub_container {
    my ( $self, $sub_container_name, $name, $c, @args ) = @_;

    my $sub_container = $self->get_sub_container( $sub_container_name );

    if (!$name) {
        my $default = $sub_container->default_component;

        return $sub_container->get_component( $default, $c, @args )
            if $default && $sub_container->has_service( $default );

        # FIXME - should I be calling $c->log->warn here?
        # this is never a controller, so this is safe
        $c->log->warn( "Calling \$c->$sub_container_name() is not supported unless you specify one of:" );
        $c->log->warn( "* \$c->config(default_$sub_container_name => 'the name of the default $sub_container_name to use')" );
        $c->log->warn( "* \$c->stash->{current_$sub_container_name} # the name of the view to use for this request" );
        $c->log->warn( "* \$c->stash->{current_${sub_container_name}_instance} # the instance of the $sub_container_name to use for this request" );

        return;
    }

    return $sub_container->get_component_regexp( $name, $c, @args )
        if ref $name;

    return $sub_container->get_component( $name, $c, @args )
        if $sub_container->has_service( $name );

    $c->log->warn(
        "Attempted to use $sub_container_name '$name', " .
        "but it does not exist"
    );

    return;
}

sub find_component {
    my ( $self, $component, $c, @args ) = @_;
    my ( $type, $name ) = _get_component_type_name($component);
    my @result;

    return $self->get_component_from_sub_container(
        $type, $name, $c, @args
    ) if $type;

    my $query = ref $component
              ? $component
              : qr{^$component$}
              ;

    for my $subcontainer_name (qw/model view controller/) {
        my $subcontainer = $self->get_sub_container( $subcontainer_name );
        my @components   = $subcontainer->get_service_list;
        @result          = grep { m{$component} } @components;

        return map { $subcontainer->get_component( $_, $c, @args ) } @result
            if @result;
    }

    # FIXME - I guess I shouldn't be calling $c->components here
    # one last search for things like $c->comp(qr/::M::/)
    @result = $self->find_component_regexp(
        $c->components, $component, $c, @args
    ) if !@result and ref $component;

    # it expects an empty list on failed searches
    return @result;
}

sub find_component_regexp {
    my ( $self, $components, $component, @args ) = @_;
    my @result;

    my @components = grep { m{$component} } keys %{ $components };

    for (@components) {
        my ($type, $name) = _get_component_type_name($_);

        push @result, $self->get_component_from_sub_container(
            $type, $name, @args
        ) if $type;
    }

    return @result;
}

# FIXME sorry for the name again :)
sub get_components_types {
    my ( $self ) = @_;
    my @comps_types;

    for my $sub_container_name (qw/model view controller/) {
        my $sub_container = $self->get_sub_container($sub_container_name);
        for my $service ( $sub_container->get_service_list ) {
            my $comp     = $self->resolve(service => $service);
            my $compname = ref $comp || $comp;
            my $type     = ref $comp ? 'instance' : 'class';
            push @comps_types, [ $compname, $type ];
        }
    }

    return @comps_types;
}

sub get_all_components {
    my $self = shift;
    my %components;

    my $containers = {
        map { $_ => $self->get_sub_container($_) } qw(model view controller)
    };

    for my $container (keys %$containers) {
        for my $component ($containers->{$container}->get_service_list) {
            my $comp = $containers->{$container}->resolve(
                service => $component
            );
            my $comp_name = ref $comp || $comp;
            $components{$comp_name} = $comp;
        }
    }

    return lock_hash %components;
}

sub add_component {
    my ( $self, $component, $class ) = @_;
    my ( $type, $name ) = _get_component_type_name($component);

    return unless $type;

    $self->get_sub_container($type)->add_service(
        Catalyst::IOC::BlockInjection->new(
            lifecycle => 'Singleton', # FIXME?
            name      => $name,
            block     => sub { $self->setup_component( $component, $class ) },
        )
    );
}

# FIXME: should this sub exist?
# should it be moved to Catalyst::Utils,
# or replaced by something already existing there?
sub _get_component_type_name {
    my ( $component ) = @_;

    my @parts = split /::/, $component;

    while (my $type = shift @parts) {
        return ('controller', join '::', @parts)
            if $type =~ /^(c|controller)$/i;

        return ('model', join '::', @parts)
            if $type =~ /^(m|model)$/i;

        return ('view', join '::', @parts)
            if $type =~ /^(v|view)$/i;
    }

    return (undef, $component);
}

# FIXME ugly and temporary
# Just moved it here the way it was, so we can work on it here in the container
sub setup_component {
    my ( $self, $component, $class ) = @_;

    unless ( $component->can( 'COMPONENT' ) ) {
        return $component;
    }

    # FIXME I know this isn't the "Dependency Injection" way of doing things,
    # its just temporary
    my $suffix = Catalyst::Utils::class2classsuffix( $component );
    my $config = $self->resolve(service => 'config')->{ $suffix } || {};

    # Stash catalyst_component_name in the config here, so that custom COMPONENT
    # methods also pass it. local to avoid pointlessly shitting in config
    # for the debug screen, as $component is already the key name.
    local $config->{catalyst_component_name} = $component;

    my $instance = eval { $component->COMPONENT( $class, $config ); };

    if ( my $error = $@ ) {
        chomp $error;
        Catalyst::Exception->throw(
            message => qq/Couldn't instantiate component "$component", "$error"/
        );
    }
    elsif (!blessed $instance) {
        my $metaclass = Moose::Util::find_meta($component);
        my $method_meta = $metaclass->find_method_by_name('COMPONENT');
        my $component_method_from = $method_meta->associated_metaclass->name;
        my $value = defined($instance) ? $instance : 'undef';
        Catalyst::Exception->throw(
            message =>
            qq/Couldn't instantiate component "$component", COMPONENT() method (from $component_method_from) didn't return an object-like value (value was $value)./
        );
    }

    return $instance;
}

sub expand_component_module {
    my ( $class, $module ) = @_;
    return Devel::InnerPackage::list_packages( $module );
}

sub locate_components {
    my ( $self, $class, $config ) = @_;

    my @paths   = qw( ::Controller ::C ::Model ::M ::View ::V );

    my $locator = Module::Pluggable::Object->new(
        search_path => [ map { s/^(?=::)/$class/; $_; } @paths ],
        %$config
    );

    # XXX think about ditching this sort entirely
    my @comps = sort { length $a <=> length $b } $locator->plugins;

    return @comps;
}

sub setup_components {
    my ( $self, $class ) = @_;

    # FIXME - should I get config as an argument, and throw the exception in
    # Catalyst.pm?
    my $config = $self->resolve(service => 'config')->{ setup_components };

    Catalyst::Exception->throw(
        qq{You are using search_extra config option. That option is\n} .
        qq{deprecated, please refer to the documentation for\n} .
        qq{other ways of achieving the same results.\n}
    ) if delete $config->{ search_extra };

    my @comps = $self->locate_components( $class, $config );
    my %comps = map { $_ => 1 } @comps;
    my $deprecatedcatalyst_component_names = 0;

    for my $component ( @comps ) {

        # We pass ignore_loaded here so that overlay files for (e.g.)
        # Model::DBI::Schema sub-classes are loaded - if it's in @comps
        # we know M::P::O found a file on disk so this is safe

        Catalyst::Utils::ensure_class_loaded( $component, { ignore_loaded => 1 } );
    }

    for my $component (@comps) {
        $self->add_component( $component, $class );
        # FIXME - $instance->expand_modules() is broken
        my @expanded_components = $self->expand_component_module( $component );

        if (
            !$deprecatedcatalyst_component_names &&
            ($deprecatedcatalyst_component_names = $component =~ m/::[CMV]::/) ||
            ($deprecatedcatalyst_component_names = grep { /::[CMV]::/ } @expanded_components)
        ) {
            # FIXME - should I be calling warn here?
            $class->log->warn(qq{Your application is using the deprecated ::[MVC]:: type naming scheme.\n}.
                qq{Please switch your class names to ::Model::, ::View:: and ::Controller: as appropriate.\n}
            );
        }

        for my $component (@expanded_components) {
            $self->add_component( $component, $class )
                unless $comps{$component};
        }
    }

    $self->get_sub_container('model')->make_single_default;
    $self->get_sub_container('view')->make_single_default;
}

1;

__END__

=pod

=head1 NAME

Catalyst::Container - IOC for Catalyst components

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head1 Containers

=head2 build_model_subcontainer

Container that stores all models.

=head2 build_view_subcontainer

Container that stores all views.

=head2 build_controller_subcontainer

Container that stores all controllers.

=head1 Services

=head2 build_application_name_service

Name of the application (such as MyApp).

=head2 build_driver_service

Config options passed directly to the driver being used.

=head2 build_file_service

?

=head2 build_substitutions_service

Executes all the substitutions in config. See L</_config_substitutions> method.

=head2 build_extensions_service

=head2 build_prefix_service

=head2 build_path_service

=head2 build_config_service

=head2 build_raw_config_service

=head2 build_global_files_service

=head2 build_local_files_service

=head2 build_global_config_service

=head2 build_local_config_service

=head2 build_config_path_service

=head2 build_config_local_suffix_service

Determines the suffix of files used to override the main config. By default
this value is C<local>, which will load C<myapp_local.conf>.  The suffix can
be specified in the following order of preference:

=over

=item * C<$ENV{ MYAPP_CONFIG_LOCAL_SUFFIX }>

=item * C<$ENV{ CATALYST_CONFIG_LOCAL_SUFFIX }>

=back

The first one of these values found replaces the default of C<local> in the
name of the local config file to be loaded.

For example, if C< $ENV{ MYAPP_CONFIG_LOCAL_SUFFIX }> is set to C<testing>,
ConfigLoader will try and load C<myapp_testing.conf> instead of
C<myapp_local.conf>.

=head2 get_component_from_sub_container($sub_container, $name, $c, @args)

Looks for components in a given subcontainer (such as controller, model or view), and returns the searched component. If $name is undef, it returns the default component (such as default_view, if $sub_container is 'view'). If $name is a regexp, it returns an array of matching components. Otherwise, it looks for the component with name $name.

=head2 get_components_types

=head2 get_all_components

Fetches all the components, in each of the sub_containers model, view and controller, and returns a readonly hash. The keys are the class names, and the values are the blessed objects. This is what is returned by $c->components.

=head2 add_component

Adds a component to the appropriate subcontainer. The subcontainer is guessed by the component name given.

=head2 find_component

Searches for components in all containers. If $component is the full class name, the subcontainer is guessed, and it gets the searched component in there. Otherwise, it looks for a component with that name in all subcontainers. If $component is a regexp, it calls the method below, find_component_regexp, and matches all components against that regexp.

=head2 find_component_regexp

Finds components that match a given regexp. Used internally, by find_component.

=head2 setup_component

=head2 _fix_syntax

=head2 _config_substitutions

This method substitutes macros found with calls to a function. There are a
number of default macros:

=over

=item * C<__HOME__> - replaced with C<$c-E<gt>path_to('')>

=item * C<__ENV(foo)__> - replaced with the value of C<$ENV{foo}>

=item * C<__path_to(foo/bar)__> - replaced with C<$c-E<gt>path_to('foo/bar')>

=item * C<__literal(__FOO__)__> - leaves __FOO__ alone (allows you to use
C<__DATA__> as a config value, for example)

=back

The parameter list is split on comma (C<,>). You can override this method to
do your own string munging, or you can define your own macros in
C<MyApp-E<gt>config-E<gt>{ 'Plugin::ConfigLoader' }-E<gt>{ substitutions }>.
Example:

    MyApp->config->{ 'Plugin::ConfigLoader' }->{ substitutions } = {
        baz => sub { my $c = shift; qux( @_ ); }
    }

The above will respond to C<__baz(x,y)__> in config strings.

=head2 $c->expand_component_module( $component, $setup_component_config )

Components found by C<locate_components> will be passed to this method, which
is expected to return a list of component (package) names to be set up.

=head2 locate_components( $setup_component_config )

This method is meant to provide a list of component modules that should be
setup for the application.  By default, it will use L<Module::Pluggable>.

Specify a C<setup_components> config option to pass additional options directly
to L<Module::Pluggable>.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
