package Catalyst::Engine::HTTP::Restarter::Watcher;

use strict;
use warnings;
use base 'Class::Accessor::Fast';
use File::Find;
use File::Modified;
use File::Spec;
use Time::HiRes qw/sleep/;

__PACKAGE__->mk_accessors( qw/delay
                              directory 
                              modified
                              regex
                              watch_list/ );

sub new {
    my ( $class, %args ) = @_;
    
    my $self = { %args };
    
    bless $self, $class;
    
    $self->_init;
    
    return $self;
}

sub _init {
    my $self = shift;
    
    my $watch_list = $self->_index_directory;
    $self->watch_list( $watch_list );
    
    $self->modified(
        File::Modified->new(
            method => 'mtime',
            files  => [ keys %{$watch_list} ],
        )
    );
}

sub watch {
    my $self = shift;
    
    my @changes;
    my @changed_files;
    
    sleep $self->delay || 1;
    
    eval { @changes = $self->modified->changed };
    if ( $@ ) {
        # File::Modified will die if a file is deleted.
        my ($deleted_file) = $@ =~ /stat '(.+)'/;
        push @changed_files, $deleted_file || 'unknown file';
    }
    
    if ( @changes ) {
        # update all mtime information
        $self->modified->update;
        
        # check if any files were changed
        @changed_files = grep { -f $_ } @changes;
        
        # Check if only directories were changed.  This means
        # a new file was created.
        unless ( @changed_files ) {
            # re-index to find new files
            my $new_watch = $self->_index_directory;
            
            # look through the new list for new files
            my $old_watch = $self->watch_list;
            @changed_files = grep { ! defined $old_watch->{$_} }
                             keys %{ $new_watch };
                             
            return unless @changed_files;
        }

        # Test modified pm's
        for my $file ( @changed_files ) {
            next unless $file =~ /\.pm$/;
            if ( my $error = $self->_test($file) ) {
                print STDERR
                  qq/File "$file" modified, not restarting\n\n/;
                print STDERR '*' x 80, "\n";
                print STDERR $error;
                print STDERR '*' x 80, "\n";
                return;
            }
        }
    }
    
    return @changed_files;
}

sub _index_directory {
    my $self = shift;
    
    my $dir   = $self->directory   || die "No directory specified";
    my $regex = $self->regex       || '\.pm$';
    my %list;
    
    finddepth(
        {
            wanted => sub {
                my $file = File::Spec->rel2abs($File::Find::name);
                return unless $file =~ /$regex/;
                return unless -f $file;
                $file =~ s{/script/..}{};
                $list{$file} = 1;
                
                # also watch the directory for changes
                my $cur_dir = File::Spec->rel2abs($File::Find::dir);
                $cur_dir =~ s{/script/..}{};                
                $list{$cur_dir} = 1;
            },
            no_chdir => 1
        },
        $dir
    );
    return \%list;
}

sub _test {
    my ( $self, $file ) = @_;
    
    delete $INC{$file};
    local $SIG{__WARN__} = sub { };
    
    open my $olderr, '>&STDERR';
    open STDERR, '>', File::Spec->devnull;
    eval "require '$file'";
    open STDERR, '>&', $olderr;
    
    return ($@) ? $@ : 0;
}    

1;
__END__

=head1 NAME

Catalyst::Engine::HTTP::Restarter::Watcher - Watch for changed application
files

=head1 SYNOPSIS

    my $watcher = Catalyst::Engine::HTTP::Restarter::Watcher->new(
        directory => '/path/to/MyApp',
        regex     => '\.yml$|\.yaml$|\.pm$',
        delay     => 1,
    );
    
    while (1) {
        my @changed_files = $watcher->watch();
    }

=head1 DESCRIPTION

This class monitors a directory of files for changes made to any file
matching a regular expression.  It correctly handles new files added to the
application as well as files that are deleted.

=head1 METHODS

=head2 new ( directory => $path [, regex => $regex, delay => $delay ] )

Creates a new Watcher object.

=head2 watch

Returns a list of files that have been added, deleted, or changed since the
last time watch was called.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Engine::HTTP::Restarter>, L<File::Modified>

=head1 AUTHORS

Sebastian Riedel, <sri@cpan.org>

Andy Grundman, <andy@hybridized.org>

=head1 THANKS

Many parts are ripped out of C<HTTP::Server::Simple> by Jesse Vincent.

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
