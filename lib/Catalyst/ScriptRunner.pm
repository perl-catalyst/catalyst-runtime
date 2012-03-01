package Catalyst::ScriptRunner;
use Moose;
use FindBin;
use lib;
use File::Spec;
use Class::Load qw/ load_first_existing_class load_optional_class /;
use Catalyst::Utils;
use namespace::autoclean -also => 'subclass_with_traits';
use Try::Tiny;

sub find_script_class {
    my ($self, $app, $script) = @_;
    return load_first_existing_class("${app}::Script::${script}", "Catalyst::Script::$script");
}

sub find_script_traits {
    my ($self, @try) = @_;

    return grep { load_optional_class($_) } @try;
}

sub subclass_with_traits {
    my ($base, @traits) = @_;

    my $meta = Class::MOP::class_of($base)->create_anon_class(
        superclasses => [ $base   ],
        roles        => [ @traits ],
        cache        => 1,
    );
    $meta->add_method(meta => sub { $meta });

    return $meta->name;
}

sub run {
    my ($self, $appclass, $scriptclass) = @_;

    if (grep { -f File::Spec->catfile($FindBin::Bin, '..', $_) } Catalyst::Utils::dist_indicator_file_list()) {
        lib->import(File::Spec->catdir($FindBin::Bin, '..', 'lib'));
    }

    my $class = $self->find_script_class($appclass, $scriptclass);

    my @possible_traits = ("${appclass}::TraitFor::Script::${scriptclass}", "${appclass}::TraitFor::Script");
    my @traits = $self->find_script_traits(@possible_traits);

    $class = subclass_with_traits($class, @traits)
        if @traits;

    $class->new_with_options( application_name => $appclass )->run;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Catalyst::ScriptRunner - The Catalyst Framework script runner

=head1 SYNOPSIS

    # Will run MyApp::Script::Server if it exists, otherwise
    # will run Catalyst::Script::Server.
    Catalyst::ScriptRunner->run('MyApp', 'Server');

=head1 DESCRIPTION

This class is responsible for loading and running scripts, either in the
application specific namespace
(e.g. C<MyApp::Script::Server>), or the Catalyst namespace (e.g. C<Catalyst::Script::Server>).

If your application contains a custom script, then it will be used in preference to the generic
script, and is expected to sub-class the standard script.

=head1 TRAIT LOADING

Catalyst will automatically load and apply roles to the scripts in your
application.

C<MyApp::TraitFor::Script> will be loaded if present, and will be applied to B<ALL>
scripts.

C<MyApp::TraitFor::Script::XXXX> will be loaded (if present) and for script
individually.

=head1 METHODS

=head2 run ($application_class, $scriptclass)

Called with two parameters, the application class (e.g. MyApp)
and the script class, (i.e. one of Server/FastCGI/CGI/Create/Test)

=head2 find_script_class ($appname, $script_name)

Finds and loads the class for the script, trying the application specific
script first, and falling back to the generic script. Returns the script
which was loaded.

=head2 find_script_traits ($appname, @try)

Finds and loads a set of traits. Returns the list of traits which were loaded.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
