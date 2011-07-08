package Catalyst::IOC::Container;
use Bread::Board;
use Moose;
use Config::Any;
use Data::Visitor::Callback;
use Catalyst::Utils ();
use MooseX::Types::LoadableClass qw/ LoadableClass /;
use Catalyst::IOC::BlockInjection;
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

has name => (
    is      => 'ro',
    isa     => 'Str',
    default => 'TestApp',
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
    my $self = shift;

    $self->add_service(
        $self->${\"build_${_}_service"}
    ) for qw/
        substitutions
        file
        driver
        name
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
        $self->${ \"build_${_}_subcontainer" }
    ) for qw/ model view controller /;
}

sub build_model_subcontainer {
    my $self = shift;

    return $self->new_sub_container(
        name => 'model',
    );
}

sub build_view_subcontainer {
    my $self = shift;

    return $self->new_sub_container(
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

    return Bread::Board::Literal->new( name => 'name', value => $self->name );
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
        name => 'extensions',
        block => sub {
            return \@{Config::Any->extensions};
        },
    );
}

sub build_prefix_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
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
        name => 'path',
        block => sub {
            my $s = shift;

            return Catalyst::Utils::env_value( $s->param('name'), 'CONFIG' )
            || $s->param('file')
            || $s->param('name')->path_to( $s->param('prefix') );
        },
        dependencies => [ depends_on('file'), depends_on('name'), depends_on('prefix') ],
    );
}

sub build_config_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
        name => 'config',
        block => sub {
            my $s = shift;

            my $v = Data::Visitor::Callback->new(
                plain_value => sub {
                    return unless defined $_;
                    return $self->_config_substitutions( $s->param('name'), $s->param('substitutions'), $_ );
                }

            );
            $v->visit( $s->param('raw_config') );
        },
        dependencies => [ depends_on('name'), depends_on('raw_config'), depends_on('substitutions') ],
    );
}

sub build_raw_config_service {
    my $self = shift;

    return Bread::Board::BlockInjection->new(
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
        name => 'config_local_suffix',
        block => sub {
            my $s = shift;
            my $suffix = Catalyst::Utils::env_value( $s->param('name'), 'CONFIG_LOCAL_SUFFIX' ) || $self->config_local_suffix;

            return $suffix;
        },
        dependencies => [ depends_on('name') ],
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

1;

__END__

=pod

=head1 NAME

Catalyst::Container - IOC for Catalyst components

=head1 METHODS

=head2 build_model_subcontainer

=head2 build_view_subcontainer

=head2 build_controller_subcontainer

=head2 build_name_service

=head2 build_driver_service

=head2 build_file_service

=head2 build_substitutions_service

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

=head2 _fix_syntax

=head2 _config_substitutions

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
