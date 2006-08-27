package Catalyst::DispatchType::Chained;

use strict;
use base qw/Catalyst::DispatchType/;
use Text::SimpleTable;
use Catalyst::ActionChain;
use URI;

# please don't perltidy this. hairy code within.

=head1 NAME

Catalyst::DispatchType::Chained - Path Part DispatchType

=head1 SYNOPSIS

  #   root action - captures one argument after it
  sub foo_setup : Chained('/') PathPart('foo') CaptureArgs(1) {
      my ( $self, $c, $foo_arg ) = @_;
      ...
  }

  #   child action endpoint - takes one argument
  sub bar : Chained('foo_setup') Args(1) {
      my ( $self, $c, $bar_arg ) = @_;
      ...
  }

=head1 DESCRIPTION

See L</USAGE>.

=head1 METHODS

=head2 $self->list($c)

Debug output for Path Part dispatch points

=cut

sub list {
    my ( $self, $c ) = @_;

    return unless $self->{endpoints};

    my $paths = Text::SimpleTable->new(
                    [ 35, 'Path Spec' ], [ 36, 'Private' ]
                );

    ENDPOINT: foreach my $endpoint (
                  sort { $a->reverse cmp $b->reverse }
                           @{ $self->{endpoints} }
                  ) {
        my $args = $endpoint->attributes->{Args}->[0];
        my @parts = (defined($args) ? (("*") x $args) : '...');
        my @parents = ();
        my $parent = "DUMMY";
        my $curr = $endpoint;
        while ($curr) {
            if (my $cap = $curr->attributes->{CaptureArgs}) {
                unshift(@parts, (("*") x $cap->[0]));
            }
            if (my $pp = $curr->attributes->{PartPath}) {
                unshift(@parts, $pp->[0])
                    if (defined $pp->[0] && length $pp->[0]);
            }
            $parent = $curr->attributes->{Chained}->[0];
            $curr = $self->{actions}{$parent};
            unshift(@parents, $curr) if $curr;
        }
        next ENDPOINT unless $parent eq '/'; # skip dangling action
        my @rows;
        foreach my $p (@parents) {
            my $name = "/${p}";
            if (my $cap = $p->attributes->{CaptureArgs}) {
                $name .= ' ('.$cap->[0].')';
            }
            unless ($p eq $parents[0]) {
                $name = "-> ${name}";
            }
            push(@rows, [ '', $name ]);
        }
        push(@rows, [ '', (@rows ? "=> " : '')."/${endpoint}" ]);
        $rows[0][0] = join('/', '', @parts);
        $paths->row(@$_) for @rows;
    }

    $c->log->debug( "Loaded Path Part actions:\n" . $paths->draw );
}

=head2 $self->match( $c, $path )

Calls C<recurse_match> to see if a chain matches the C<$path>.

=cut

sub match {
    my ( $self, $c, $path ) = @_;

    return 0 if @{$c->req->args};

    my @parts = split('/', $path);

    my ($chain, $captures) = $self->recurse_match($c, '/', \@parts);

    return 0 unless $chain;

    my $action = Catalyst::ActionChain->from_chain($chain);

    $c->req->action("/${action}");
    $c->req->match("/${action}");
    $c->req->captures($captures);
    $c->action($action);
    $c->namespace( $action->namespace );

    return 1;
}

=head2 $self->recurse_match( $c, $parent, \@path_parts )

Recursive search for a matching chain.

=cut

sub recurse_match {
    my ( $self, $c, $parent, $path_parts ) = @_;
    my $children = $self->{children_of}{$parent};
    return () unless $children;
    my @captures;
    TRY: foreach my $try_part (sort { length($b) <=> length($a) }
                                   keys %$children) {
                               # $b then $a to try longest part first
        my @parts = @$path_parts;
        if (length $try_part) { # test and strip PathPart
            next TRY unless
              ($try_part eq join('/', # assemble equal number of parts
                              splice( # and strip them off @parts as well
                                @parts, 0, scalar(@{[split('/', $try_part)]})
                              ))); # @{[]} to avoid split to @_
        }
        my @try_actions = @{$children->{$try_part}};
        TRY_ACTION: foreach my $action (@try_actions) {
            if (my $capture_attr = $action->attributes->{CaptureArgs}) {
                my @captures;
                my @parts = @parts; # localise

                # strip CaptureArgs into list
                push(@captures, splice(@parts, 0, $capture_attr->[0]));

                # try the remaining parts against children of this action
                my ($actions, $captures) = $self->recurse_match(
                                             $c, '/'.$action->reverse, \@parts
                                           );
                if ($actions) {
                    return [ $action, @$actions ], [ @captures, @$captures ];
                }
            } else {
                {
                    local $c->req->{arguments} = [ @{$c->req->args}, @parts ];
                    next TRY_ACTION unless $action->match($c);
                }
                push(@{$c->req->args}, @parts);
                return [ $action ], [ ];
            }
        }
    }
    return ();
}

=head2 $self->register( $c, $action )

Calls register_path for every Path attribute for the given $action.

=cut

sub register {
    my ( $self, $c, $action ) = @_;

    my @chained_attr = @{ $action->attributes->{Chained} || [] };

    return 0 unless @chained_attr;

    if (@chained_attr > 2) {
        Catalyst::Exception->throw(
          "Multiple Chained attributes not supported registering ${action}"
        );
    }

    my $parent = $chained_attr[0];

    if (defined($parent) && length($parent)) {
        if ($parent eq '.') {
            $parent = '/'.$action->namespace;
        } elsif ($parent !~ m/^\//) {
            if ($action->namespace) {
                $parent = '/'.join('/', $action->namespace, $parent);
            } else {
                $parent = '/'.$parent; # special case namespace '' (root)
            }
        }
    } else {
        $parent = '/'
    }

    $action->attributes->{Chained} = [ $parent ];

    my $children = ($self->{children_of}{$parent} ||= {});

    my @path_part = @{ $action->attributes->{PathPart} || [] };

    my $part = $action->name;

    if (@path_part == 1 && defined $path_part[0]) {
        $part = $path_part[0];
    } elsif (@path_part > 1) {
        Catalyst::Exception->throw(
          "Multiple PathPart attributes not supported registering ${action}"
        );
    }

    if ($part =~ m(^/)) {
        Catalyst::Exception->throw(
          "Absolute parameters to PathPart not allowed registering ${action}"
        );
    }

    $action->attributes->{PartPath} = [ $part ];

    unshift(@{ $children->{$part} ||= [] }, $action);

    ($self->{actions} ||= {})->{'/'.$action->reverse} = $action;

    unless ($action->attributes->{CaptureArgs}) {
        unshift(@{ $self->{endpoints} ||= [] }, $action);
    }

    return 1;
}

=head2 $self->uri_for_action($action, $captures)

Get the URI part for the action, using C<$captures> to fill
the capturing parts.

=cut

sub uri_for_action {
    my ( $self, $action, $captures ) = @_;

    return undef unless ($action->attributes->{Chained}
                           && !$action->attributes->{CaptureArgs});

    my @parts = ();
    my @captures = @$captures;
    my $parent = "DUMMY";
    my $curr = $action;
    while ($curr) {
        if (my $cap = $curr->attributes->{CaptureArgs}) {
            return undef unless @captures >= $cap->[0]; # not enough captures
            if ($cap->[0]) {
                unshift(@parts, splice(@captures, -$cap->[0]));
            }
        }
        if (my $pp = $curr->attributes->{PartPath}) {
            unshift(@parts, $pp->[0])
                if (defined($pp->[0]) && length($pp->[0]));
        }
        $parent = $curr->attributes->{Chained}->[0];
        $curr = $self->{actions}{$parent};
    }

    return undef unless $parent eq '/'; # fail for dangling action

    return undef if @captures; # fail for too many captures

    return join('/', '', @parts);
   
}

=head1 USAGE

=head2 Introduction

The C<Chained> attribute allows you to chain public path parts together
by their private names. A chain part's path can be specified with
C<PathPart> and can be declared to expect an arbitrary number of
arguments. The endpoint of the chain specifies how many arguments it
gets through the C<Args> attribute. C<:Args(0)> would be none at all,
C<:Args> without an integer would be unlimited. The path parts that
aren't endpoints are using C<CaptureArgs> to specify how many parameters
they expect to receive. As an example setup:

  package MyApp::Controller::Greeting;
  use base qw/ Catalyst::Controller /;

  #   this is the beginning of our chain
  sub hello : PathPart('hello') Chained('/') CaptureArgs(1) {
      my ( $self, $c, $integer ) = @_;
      $c->stash->{ message } = "Hello ";
      $c->stash->{ arg_sum } = $integer;
  }

  #   this is our endpoint, because it has no :CaptureArgs
  sub world : PathPart('world') Chained('hello') Args(1) {
      my ( $self, $c, $integer ) = @_;
      $c->stash->{ message } .= "World!";
      $c->stash->{ arg_sum } += $integer;

      $c->response->body( join "<br/>\n" =>
          $c->stash->{ message }, $c->stash->{ arg_sum } );
  }

The debug output provides a separate table for chained actions, showing
the whole chain as it would match and the actions it contains. Here's an
example of the startup output with our actions above:

  ...
  [debug] Loaded Path Part actions:
  .-----------------------+------------------------------.
  | Path Spec             | Private                      |
  +-----------------------+------------------------------+
  | /hello/*/world/*      | /greeting/hello (1)          |
  |                       | => /greeting/world           |
  '-----------------------+------------------------------'
  ...

As you can see, Catalyst only deals with chains as whole paths and
builds one for each endpoint, which are the actions with C<:Chained> but
without C<:CaptureArgs>.

Let's assume this application gets a request at the path
C</hello/23/world/12>. What happens then? First, Catalyst will dispatch
to the C<hello> action and pass the value C<23> as an argument to it
after the context. It does so because we have previously used
C<:CaptureArgs(1)> to declare that it has one path part after itself as
its argument. We told Catalyst that this is the beginning of the chain
by specifying C<:Chained('/')>. Also note that instead of saying
C<:PathPart('hello')> we could also just have said C<:PathPart>, as it
defaults to the name of the action.

After C<hello> has run, Catalyst goes on to dispatch to the C<world>
action. This is the last action to be called: Catalyst knows this is an
endpoint because we did not specify a C<:CaptureArgs>
attribute. Nevertheless we specify that this action expects an argument,
but at this point we're using C<:Args(1)> to do that. We could also have
said C<:Args> or left it out altogether, which would mean this action
would get all arguments that are there. This action's C<:Chained>
attribute says C<hello> and tells Catalyst that the C<hello> action in
the current controller is its parent.

With this we have built a chain consisting of two public path parts.
C<hello> captures one part of the path as its argument, and also
specifies the path root as its parent. So this part is
C</hello/$arg>. The next part is the endpoint C<world>, expecting one
argument. It sums up to the path part C<world/$arg>. This leads to a
complete chain of C</hello/$arg/world/$arg> which is matched against the
requested paths.

This example application would, if run and called by e.g.
C</hello/23/world/12>, set the stash value C<message> to "Hello" and the
value C<arg_sum> to "23". The C<world> action would then append "World!"
to C<message> and add C<12> to the stash's C<arg_sum> value.  For the
sake of simplicity no view is shown. Instead we just put the values of
the stash into our body. So the output would look like:

  Hello World!
  35

And our test server would have given us this debugging output for the
request:

  ...
  [debug] "GET" request for "hello/23/world/12" from "127.0.0.1"
  [debug] Path is "/greeting/world"
  [debug] Arguments are "12"
  [info] Request took 0.164113s (6.093/s)
  .------------------------------------------+-----------.
  | Action                                   | Time      |
  +------------------------------------------+-----------+
  | /greeting/hello                          | 0.000029s |
  | /greeting/world                          | 0.000024s |
  '------------------------------------------+-----------'
  ...

What would be common uses of this dispatch technique? It gives the
possibility to split up logic that contains steps that each depend on
each other. An example would be, for example, a wiki path like
C</wiki/FooBarPage/rev/23/view>. This chain can be easily built with
these actions:

  sub wiki : PathPart('wiki') Chained('/') CaptureArgs(1) {
      my ( $self, $c, $page_name ) = @_;
      #  load the page named $page_name and put the object
      #  into the stash
  }

  sub rev : PathPart('rev') Chained('wiki') CaptureArgs(1) {
      my ( $self, $c, $revision_id ) = @_;
      #  use the page object in the stash to get at its
      #  revision with number $revision_id
  }

  sub view : PathPart Chained('rev') Args(0) {
      my ( $self, $c ) = @_;
      #  display the revision in our stash. Another option
      #  would be to forward a compatible object to the action
      #  that displays the default wiki pages, unless we want
      #  a different interface here, for example restore
      #  functionality.
  }

It would now be possible to add other endpoints, for example C<restore>
to restore this specific revision as the current state.

You don't have to put all the chained actions in one controller. The
specification of the parent through C<:Chained> also takes an absolute
action path as its argument. Just specify it with a leading C</>.

If you want, for example, to have actions for the public paths
C</foo/12/edit> and C</foo/12>, just specify two actions with
C<:PathPart('foo')> and C<:Chained('/')>. The handler for the former
path needs a C<:CaptureArgs(1)> attribute and a endpoint with
C<:PathPart('edit')> and C<:Chained('foo')>. For the latter path give
the action just a C<:Args(1)> to mark it as endpoint. This sums up to
this debugging output:

  ...
  [debug] Loaded Path Part actions:
  .-----------------------+------------------------------.
  | Path Spec             | Private                      |
  +-----------------------+------------------------------+
  | /foo/*                | /controller/foo_view         |
  | /foo/*/edit           | /controller/foo_load (1)     |
  |                       | => /controller/edit          |
  '-----------------------+------------------------------'
  ...

Here's a more detailed specification of the attributes belonging to 
C<:Chained>:

=head2 Attributes

=over 8

=item PathPart

Sets the name of this part of the chain. If it is specified without
arguments, it takes the name of the action as default. So basically
C<sub foo :PathPart> and C<sub foo :PathPart('foo')> are identical.
This can also contain slashes to bind to a deeper level. An action
with C<sub bar :PathPart('foo/bar') :Chained('/')> would bind to
C</foo/bar/...>. If you don't specify C<:PathPart> it has the same
effect as using C<:PathPart>, it would default to the action name.

=item Chained

Has to be specified for every child in the chain. Possible values are
absolute and relative private action paths, with the relatives pointing
to the current controller, or a single slash C</> to tell Catalyst that
this is the root of a chain. The attribute C<:Chained> without aguments
also defaults to the C</> behavior.

Because you can specify an absolute path to the parent action, it
doesn't matter to Catalyst where that parent is located. So, if your
design requests it, you can redispatch a chain through any controller or
namespace you want.

Another interesting possibility gives C<:Chained('.')>, which chains
itself to an action with the path of the current controller's namespace.
For example:

  #   in MyApp::Controller::Foo
  sub bar : Chained CaptureArgs(1) { ... }

  #   in MyApp::Controller::Foo::Bar
  sub baz : Chained('.') Args(1) { ... }

This builds up a chain like C</bar/*/baz/*>. The specification of C<.>
as the argument to Chained here chains the C<baz> action to an action
with the path of the current controller namespace, namely
C</foo/bar>. That action chains directly to C</>, so the C</bar/*/baz/*>
chain comes out as the end product.

=item CaptureArgs

Must be specified for every part of the chain that is not an
endpoint. With this attribute Catalyst knows how many of the following
parts of the path (separated by C</>) this action wants to capture as
its arguments. If it doesn't expect any, just specify
C<:CaptureArgs(0)>.  The captures get passed to the action's C<@_> right
after the context, but you can also find them as array references in
C<$c-E<gt>request-E<gt>captures-E<gt>[$level]>. The C<$level> is the
level of the action in the chain that captured the parts of the path.

An action that is part of a chain (that is, one that has a C<:Chained>
attribute) but has no C<:CaptureArgs> attribute is treated by Catalyst
as a chain end.

=item Args

By default, endpoints receive the rest of the arguments in the path. You
can tell Catalyst through C<:Args> explicitly how many arguments your
endpoint expects, just like you can with C<:CaptureArgs>. Note that this
also affects whether this chain is invoked on a request. A chain with an
endpoint specifying one argument will only match if exactly one argument
exists in the path.

You can specify an exact number of arguments like C<:Args(3)>, including
C<0>. If you just say C<:Args> without any arguments, it is the same as
leaving it out altogether: The chain is matched regardless of the number
of path parts after the endpoint.

Just as with C<:CaptureArgs>, the arguments get passed to the action in
C<@_> after the context object. They can also be reached through
C<$c-E<gt>request-E<gt>arguments>.

=back

=head2 Auto actions, dispatching and forwarding

Note that the list of C<auto> actions called depends on the private path
of the endpoint of the chain, not on the chained actions way. The
C<auto> actions will be run before the chain dispatching begins. In
every other aspect, C<auto> actions behave as documented.

The C<forward>ing to other actions does just what you would expect. But if
you C<detach> out of a chain, the rest of the chain will not get called
after the C<detach>.

=head1 AUTHOR

Matt S Trout <mst@shadowcatsystems.co.uk>

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
