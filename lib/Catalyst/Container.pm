package Catalyst::Container;
use Bread::Board;
use Moose;
use Config::Any;
use Data::Visitor::Callback;
use Catalyst::Utils ();

extends 'Bread::Board::Container';

has config_local_suffix => (
    is      => 'rw',
    isa     => 'Str',
    default => 'local',
);

has driver => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
);

has file => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
);

has substitutions => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
);

has name => (
    is      => 'rw',
    isa     => 'Str',
    default => 'TestApp',
);

sub BUILD {
    my $self = shift;

    container $self => as {
        service name => $self->name;
        service driver => $self->driver;
        service file => $self->file;
        service substitutions => $self->substitutions;

        service extensions => (
            block => sub {
                return \@{Config::Any->extensions};
            },
        );

        service prefix => (
            block => sub {
                return Catalyst::Utils::appprefix( shift->param('name') );
            },
            dependencies => [ depends_on('name') ],
         );

        service path => (
            block => sub {
                my $s = shift;

                return Catalyst::Utils::env_value( $s->param('name'), 'CONFIG' )
                || $s->param('file')
                || $s->param('name')->path_to( $s->param('prefix') );
            },
            dependencies => [ depends_on('file'), depends_on('name'), depends_on('prefix') ],
        );

        service config => (
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

        service raw_config => (
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

        service global_files => (
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

        service local_files => (
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

        service global_config => (
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

        service local_config => (
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

        service config_path => (
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

        service config_local_suffix => (
            block => sub {
                my $s = shift;
                my $suffix = Catalyst::Utils::env_value( $s->param('name'), 'CONFIG_LOCAL_SUFFIX' ) || $self->config_local_suffix;

                return $suffix;
            },
            dependencies => [ depends_on('name') ],
        );

    };
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
    my ($self, $name, $subs) = @_;

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

    for ( @_ ) {
        my $arg = $_;
        $arg =~ s{__($subsre)(?:\((.+?)\))?__}{ $subs->{ $1 }->( $name, $2 ? split( /,/, $2 ) : () ) }eg;
        return $arg;
    }
}

1;
