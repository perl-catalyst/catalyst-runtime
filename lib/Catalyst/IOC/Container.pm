package Catalyst::IOC::Container;
use Bread::Board qw/depends_on/;
use Moose;
use Config::Any;
use Data::Visitor::Callback;
use Catalyst::Utils ();
use List::Util qw(first);
use Devel::InnerPackage ();
use Hash::Util qw/lock_hash/;
use MooseX::Types::LoadableClass qw/ LoadableClass /;
use Moose::Util;
use Scalar::Util qw/refaddr/;
use Catalyst::IOC::BlockInjection;
use Catalyst::IOC::ConstructorInjection;
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
        class_config
        config_local_suffix
        config_path
        locate_components
    /;

    my $config = $self->resolve( service => 'config' );

    # don't force default_component to be undef if the config wasn't set
    my @default_view  = $config->{default_view}
                      ? ( default_component => $config->{default_view} )
                      : ( )
                      ;
    my @default_model = $config->{default_model}
                      ? ( default_component => $config->{default_model} )
                      : ( )
                      ;

    $self->add_sub_container(
        $self->build_component_subcontainer
    );

    $self->add_sub_container(
        $self->build_controller_subcontainer
    );

    $self->add_sub_container(
        $self->build_view_subcontainer( @default_view )
    );

    $self->add_sub_container(
        $self->build_model_subcontainer( @default_model )
    );

    {
        no strict 'refs';
        no warnings 'once';
        my $class = ref $self;
        ${ $class . '::customise_container' }->($self)
            if ${ $class . '::customise_container' };
    }
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

sub build_component_subcontainer {
    my $self = shift;

    return Bread::Board::Container->new(
        name => 'component',
    );
}

sub build_home_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'home',
        block => sub {
            my $self = shift;
            my $class = $self->param('application_name');
            my $home;

            if ( my $env = Catalyst::Utils::env_value( $class, 'HOME' ) ) {
                $home = $env;
            }

            $home ||= Catalyst::Utils::home($class);
            return $home;
        },
        dependencies => [ depends_on('application_name') ],
    );
}

# FIXME: very ambiguous - maybe root_dir?
sub build_root_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'root',
        block => sub {
            my $self = shift;

            return Path::Class::Dir->new( $self->param('home') )->subdir('root');
        },
        dependencies => [ depends_on('home') ],
    );
}

sub build_application_name_service {
    my $self = shift;

    return Bread::Board::Literal->new( name => 'application_name', value => $self->name );
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
            return Catalyst::Utils::appprefix( shift->param('application_name') );
        },
        dependencies => [ depends_on('application_name') ],
    );
}

sub build_path_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'path',
        block => sub {
            my $s = shift;

            return Catalyst::Utils::env_value( $s->param('application_name'), 'CONFIG' )
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

            my $config = $s->param('class_config');

            for my $cfg (@global, @locals) {
                for (keys %$cfg) {
                    $config = Catalyst::Utils::merge_hashes( $config, $cfg->{$_} );
                }
            }

            return $config;
        },
        dependencies => [ depends_on('global_config'), depends_on('local_config'), depends_on('class_config') ],
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

sub build_class_config_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name => 'class_config',
        block => sub {
            my $s   = shift;
            my $app = $s->param('application_name');

            # Container might be called outside Catalyst context
            return {} unless Class::MOP::is_class_loaded($app);

            # config might not have been defined
            return $app->config || {};
        },
        dependencies => [ depends_on('application_name') ],
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

sub build_locate_components_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        lifecycle => 'Singleton',
        name      => 'locate_components',
        block     => sub {
            my $s      = shift;
            my $class  = $s->param('application_name');
            my $config = $s->param('config')->{ setup_components };

            Catalyst::Exception->throw(
                qq{You are using search_extra config option. That option is\n} .
                qq{deprecated, please refer to the documentation for\n} .
                qq{other ways of achieving the same results.\n}
            ) if delete $config->{ search_extra };

            my @paths = qw( ::Controller ::C ::Model ::M ::View ::V );

            my $locator = Module::Pluggable::Object->new(
                search_path => [ map { s/^(?=::)/$class/; $_; } @paths ],
                %$config
            );

            return [ $locator->plugins ];
        },
        dependencies => [ depends_on('application_name'), depends_on('config') ],
    );
}

sub setup_components {
    my $self = shift;
    my $class = $self->resolve( service => 'application_name' );
    my @comps = @{ $self->resolve( service => 'locate_components' ) };
    my %comps = map { $_ => 1 } @comps;
    my $deprecatedcatalyst_component_names = 0;

    my $app_locate_components_addr = refaddr(
        $class->can('locate_components')
    );
    my $cat_locate_components_addr = refaddr(
        Catalyst->can('locate_components')
    );

    if ($app_locate_components_addr != $cat_locate_components_addr) {
        # FIXME - why not just say: @comps = $class->locate_components() ?
        $class->log->warn(qq{You have overridden locate_components. That } .
            qq{no longer works. Please refer to the documentation to achieve } .
            qq{similar results.\n}
        );
    }

    for my $component ( @comps ) {

        # We pass ignore_loaded here so that overlay files for (e.g.)
        # Model::DBI::Schema sub-classes are loaded - if it's in @comps
        # we know M::P::O found a file on disk so this is safe

        Catalyst::Utils::ensure_class_loaded( $component, { ignore_loaded => 1 } );
    }

    for my $component (@comps) {
        $self->add_component( $component );
        # FIXME - $instance->expand_modules() is broken
        my @expanded_components = $self->expand_component_module( $component );

        if (
            !$deprecatedcatalyst_component_names &&
            ($deprecatedcatalyst_component_names = $component =~ m/::[CMV]::/) ||
            ($deprecatedcatalyst_component_names = grep { /::[CMV]::/ } @expanded_components)
        ) {
            # FIXME - should I be calling warn here?
            # Maybe it's time to remove it, or become fatal
            $class->log->warn(qq{Your application is using the deprecated ::[MVC]:: type naming scheme.\n}.
                qq{Please switch your class names to ::Model::, ::View:: and ::Controller: as appropriate.\n}
            );
        }

        for my $component (@expanded_components) {
            $self->add_component( $component )
                unless $comps{$component};
        }
    }
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
    my ( $self, $component, @args ) = @_;
    my ( $type, $name ) = _get_component_type_name($component);
    my @result;

    return $self->get_component_from_sub_container(
        $type, $name, @args
    ) if $type;

    my $query = ref $component
              ? $component
              : qr{^$component$}
              ;

    for my $subcontainer_name (qw/model view controller/) {
        my $subcontainer = $self->get_sub_container( $subcontainer_name );
        my @components   = $subcontainer->get_service_list;
        @result          = grep { m{$component} } @components;

        return map { $subcontainer->get_component( $_, @args ) } @result
            if @result;
    }

    # one last search for things like $c->comp(qr/::M::/)
    @result = $self->_find_component_regexp(
        $component, @args
    ) if !@result and ref $component;

    # it expects an empty list on failed searches
    return @result;
}

sub _find_component_regexp {
    my ( $self, $component, $ctx, @args ) = @_;
    my @result;

    my @components = grep { m{$component} } keys %{ $self->get_all_components($ctx) };

    for (@components) {
        my ($type, $name) = _get_component_type_name($_);

        push @result, $self->get_component_from_sub_container(
            $type, $name, $ctx, @args
        ) if $type;
    }

    return @result;
}

sub get_all_components {
    my ($self, $class) = @_;
    my %components;

    # FIXME - if we're getting from these containers, we need to either:
    #   - pass 'ctx' and 'accept_context_args' OR
    #   - make these params optional
    # big problem when setting up the dispatcher - this method is called
    # as $container->get_all_components('MyApp'). What to do with Request
    # life cycles?
    foreach my $type (qw/model view controller /) {
        my $container = $self->get_sub_container($type);

        for my $component ($container->get_service_list) {
            my $comp_service = $container->get_service($component);

            $components{$comp_service->catalyst_component_name} = $comp_service->get(ctx => $class);
        }
    }

    return lock_hash %components;
}

sub add_component {
    my ( $self, $component ) = @_;
    my ( $type, $name ) = _get_component_type_name($component);

    return unless $type;

    # The 'component' sub-container will create the object, and store it's
    # instance, which, by default, will live throughout the application.
    # The model/view/controller sub-containers only reference the instance
    # held in the aforementioned sub-container, and execute the ACCEPT_CONTEXT
    # sub every time they are called, when it exists.
    my $instance_container       = $self->get_sub_container('component');
    my $accept_context_container = $self->get_sub_container($type);

    # Custom containers might have added the service already
    # We don't want to override that
    return if $accept_context_container->has_service( $name );

    my $component_service_name = "${type}_${name}";

    $instance_container->add_service(
        Catalyst::IOC::ConstructorInjection->new(
            name      => $component_service_name,
            catalyst_component_name => $component,
            class     => $component,
            lifecycle => 'Singleton',
            dependencies => [
                depends_on( '/application_name' ),
            ],
        ),
    );
    # XXX - FIXME - We have to explicitly build the service here,
    #               causing the COMPONENT method to be called early here, as otherwise
    #               if the component method defines other classes (e.g. the
    #               ACCEPT_CONTEXT injection Model::DBIC::Schema does)
    #               then they won't be found by Devel::InnerPackage
    # see also t/aggregate/unit_core_component_loading.t
    $instance_container->get_service($component_service_name)->get;

    $accept_context_container->add_service(
        Catalyst::IOC::BlockInjection->new(
            name         => $name,
            catalyst_component_name => $component,
            dependencies => [
                depends_on( "/component/$component_service_name" ),
            ],
            block => sub { shift->param($component_service_name) },
        )
    );
}

# FIXME: should this sub exist?
# should it be moved to Catalyst::Utils,
# or replaced by something already existing there?
sub _get_component_type_name {
    my ( $component ) = @_;
    my $result;

    while ( !$result and (my $index = index $component, '::') > 0 ) {
        my $type   = lc substr $component, 0, $index;
        $component = substr $component, $index + 2;
        $result    = first { $type eq $_ or $type eq substr($_, 0, 1) }
                         qw{ model view controller };
    }

    return ($result, $component);
}

sub expand_component_module {
    my ( $class, $module ) = @_;
    return Devel::InnerPackage::list_packages( $module );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 NAME

Catalyst::Container - IOC for Catalyst components

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head1 Methods for Building Containers

=head2 build_component_subcontainer

Container that stores all components, i.e. all models, views and controllers
together. Each service is an instance of the actual component, and by default
it lives while the application is running. Retrieving components from this
sub-container will instantiate the component, if it hasn't been instantiated
already, but will not execute ACCEPT_CONTEXT.

=head2 build_model_subcontainer

Container that stores references for all models that are inside the components
sub-container. Retrieving a model triggers ACCEPT_CONTEXT, if it exists.

=head2 build_view_subcontainer

Same as L<build_model_subcontainer>, but for views.

=head2 build_controller_subcontainer

Same as L<build_model_subcontainer>, but for controllers.

=head1 Methods for Building Services

=head2 build_application_name_service

Name of the application (such as MyApp).

=head2 build_driver_service

Config options passed directly to the driver being used.

=head2 build_file_service

?

=head2 build_substitutions_service

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
C<< <MyApp->config( 'Plugin::ConfigLoader' => { substitutions => { ... } } ) >>.
Example:

    MyApp->config( 'Plugin::ConfigLoader' => {
        substitutions => {
            baz => sub { my $c = shift; qux( @_ ); },
        },
    });

The above will respond to C<__baz(x,y)__> in config strings.

=head2 build_extensions_service

Config::Any's available config file extensions (e.g. xml, json, pl, etc).

=head2 build_prefix_service

The prefix, based on the application name, that will be used to look-up the
config files (which will be in the format $prefix.$extension). If the app is
MyApp::Foo, the prefix will be myapp_foo.

=head2 build_path_service

The path to the config file (or environment variable, if defined).

=head2 build_config_service

The resulting configuration for the application, after it has successfully
been loaded, and all substitutions have been made.

=head2 build_raw_config_service

The merge of local_config and global_config hashes, before substitutions.

=head2 build_global_files_service

Gets all files for config that don't have the local_suffix, such as myapp.conf.

=head2 build_local_files_service

Gets all files for config that have the local_suffix, such as myapp_local.conf.

=head2 build_global_config_service

Reads config from global_files.

=head2 build_local_config_service

Reads config from local_files.

=head2 build_class_config_service

Reads config set from the application's class attribute config,
i.e. MyApp->config( name => 'MyApp', ... )

=head2 build_config_path_service

Splits the path to the config file, and returns on array ref containing
the path to the config file minus the extension in the first position,
and the extension in the second.

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

=head2 build_locate_components_service

This method is meant to provide a list of component modules that should be
setup for the application.  By default, it will use L<Module::Pluggable>.

Specify a C<setup_components> config option to pass additional options directly
to L<Module::Pluggable>.

=head1 Other methods

=head2 get_component_from_sub_container($sub_container, $name, $c, @args)

Looks for components in a given sub-container (such as controller, model or
view), and returns the searched component. If $name is undef, it returns the
default component (such as default_view, if $sub_container is 'view'). If
$name is a regexp, it returns an array of matching components. Otherwise, it
looks for the component with name $name.

=head2 get_all_components

Fetches all the components, in each of the sub_containers model, view and
controller, and returns a read-only hash. The keys are the class names, and
the values are the blessed objects. This is what is returned by $c->components.

=head2 add_component

Adds a component to the appropriate sub-container. The sub-container is guessed
by the component name given.

=head2 find_component

Searches for components in all containers. If $component is the full class
name, the sub-container is guessed, and it gets the searched component in there.
Otherwise, it looks for a component with that name in all sub-containers. If
$component is a regexp it calls _find_component_regexp and matches all
components against that regexp.

=head2 expand_component_module

Components found by C<locate_components> will be passed to this method, which
is expected to return a list of component (package) names to be set up.

=head2 setup_components

Uses locate_components service to list the components, and adds them to the
appropriate sub-containers, using add_component().

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
