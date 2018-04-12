package Catalyst::ActionRole::QueryMatching;

use Moose::Role;
use Moose::Util::TypeConstraints ();

requires 'match', 'match_captures', 'list_extra_info';

sub _query_attr { @{shift->attributes->{Query}||[]} }

has is_slurpy => (
  is=>'ro',
  init_arg=>undef,
  isa=>'Bool',
  required=>1,
  lazy=>1,
  builder=>'_build_is_slurpy');

  sub _build_is_slurpy {
    my $self = shift;
    my($query, @extra) = $self->_query_attr;
    return $query =~m/^.+,\.\.\.$/ ? 1:0;
  }

has query_constraints => (
  is=>'ro',
  init_arg=>undef,
  isa=>'ArrayRef|Ref',
  required=>1,
  lazy=>1,
  builder=>'_build_query_constraints');

  sub _build_query_constraints {
    my $self = shift;
    my ($constraint_proto, @extra) = $self->_query_attr;

    die "Action ${\$self->private_path} defines more than one 'Query' attribute" if scalar @extra;
    return +{} unless defined($constraint_proto);

    $constraint_proto =~s/^(.+),\.\.\.$/$1/; # slurpy is handled elsewhere

    # Query may be a Hash like Query(p=>Int,q=>Str) OR it may be a Ref like
    # Query(Tuple[p=>Int, slurpy HashRef]).  The only way to figure is to eval it
    # and look at what we have.
    my @signature = eval "package ${\$self->class}; $constraint_proto"
      or die "'$constraint_proto' is not valid Query Contraint at action ${\$self->private_path}, error '$@'";

    if(scalar(@signature) > 1) {
      # Do a dance to support old school stringy types
      # At this point we 'should' have a hash...
      my %pairs = @signature;
      foreach my $key(keys %pairs) {
        next if ref $pairs{$key};
        $pairs{$key} = Moose::Util::TypeConstraints::find_or_parse_type_constraint($pairs{$key}) ||
          die "'$pairs{$key}' is not a valid type constraint in Action ${\$self->private_path}";
      }
      return \%pairs;
    } else {
      # We have a 'reference type' constraint, like Dict[p=>Int,...]
      return $signature[0] if ref($signature[0]); # Is like Tiny::Type
      return Moose::Util::TypeConstraints::find_or_parse_type_constraint($signature[0]) ||
          die "'$signature[0]' is not a valid type constraint in Action ${\$self->private_path}";
    }
  }

around ['match','match_captures'] => sub {
    my ($orig, $self, $c, @args) = @_;
    my $tc = $self->query_constraints;
    if(ref $tc eq 'HASH') {
      # Do the key names match, unless slurpy?
      unless($self->is_slurpy) {
        return 0 unless $self->_compare_arrays([sort keys %$tc],[sort keys %{$c->req->query_parameters}]);
      }
      for my $key(keys %$tc) {
        $tc->{$key}->check($c->req->query_parameters->{$key}) || return 0;
      }
    } else {
      $tc->check($c->req->query_parameters) || return 0;
    }

    return $self->$orig($c, @args);
};

around 'list_extra_info' => sub {
  my ($orig, $self, @args) = @_;
  return {
    %{ $self->$orig(@args) },
  };
};

sub _compare_arrays {
  my ($self, $first, $second) = @_;
  no warnings;  # silence spurious -w undef complaints
  return 0 unless @$first == @$second;
  for (my $i = 0; $i < @$first; $i++) {
    return 0 if $first->[$i] ne $second->[$i];
  }
  return 1;
}

1;

=head1 NAME

Catalyst::ActionRole::QueryMatching - Match on GET parameters using type constraints

=head1 SYNOPSIS

    TBD

=head1 DESCRIPTION

    TBD

=head1 METHODS

This role defines the following methods

=head2 TBD

    TBD

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
