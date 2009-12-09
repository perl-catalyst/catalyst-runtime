package Catalyst::ScriptRunner;
use Moose;
use FindBin;
use lib;
use File::Spec;
use namespace::autoclean -also => 'subclass_with_traits';
use Try::Tiny;

sub find_script_class {
    my ($self, $app, $script) = @_;
    my $class = "${app}::Script::${script}";

    try {
        Class::MOP::load_class($class);
    }
    catch {
        confess $_ unless /Can't locate/;
        $class = "Catalyst::Script::$script";
    };

    Class::MOP::load_class($class);
    return $class;
}

sub find_script_traits {
    my ($self, @try) = @_;

    my @traits;
    for my $try (@try) {
        try {
            Class::MOP::load_class($try);
            push @traits, $try;
        }
        catch {
            confess $_ unless /^Can't locate/;
        };
    }

    return @traits;
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

    lib->import(File::Spec->catdir($FindBin::Bin, '..', 'lib'));

    my $class = $self->find_script_class($appclass, $scriptclass);

    my @possible_traits = ("${appclass}::TraitFor::Script::${scriptclass}", "${appclass}::TraitFor::Script");
    my @traits = $self->find_script_traits(@possible_traits);

    $class = subclass_with_traits($class, @traits)
        if @traits;

    $class->new_with_options( application_name => $appclass )->run;
}

__PACKAGE__->meta->make_immutable;

=head1 NAME

Catalyst::ScriptRunner - The Catalyst Framework script runner

=head1 SYNOPSIS

    # Will run MyApp::Script::Server if it exists, otherwise
    # will run Catalyst::Script::Server.
    Catalyst::ScriptRunner->run('MyApp', 'Server');

=head1 DESCRIPTION

This class is responsible for running scripts, either in the application specific namespace
(e.g. C<MyApp::Script::Server>), or the Catalyst namespace (e.g. C<Catalyst::Script::Server>)

=head1 METHODS

=head2 run ($application_class, $scriptclass)

Called with two parameters, the application class (e.g. MyApp)
and the script class, (i.e. one of Server/FastCGI/CGI/Create/Test)

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
