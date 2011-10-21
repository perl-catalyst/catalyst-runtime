package Catalyst::ClassData;

use Moose::Role;
use Moose::Meta::Class ();
use Class::MOP;
use Moose::Util ();

sub mk_classdata {
  my ($class, $attribute, $warn_on_instance) = @_;
  confess("mk_classdata() is a class method, not an object method")
    if blessed $class;

  my $slot = '$'.$attribute;
  my $accessor =  sub {
    my $pkg = ref $_[0] || $_[0];
    my $meta = Moose::Util::find_meta($pkg)
        || Moose::Meta::Class->initialize( $pkg );
    if (@_ > 1) {
      $meta->namespace->{$attribute} = \$_[1];
      return $_[1];
    }

    # tighter version of
    # if ( $meta->has_package_symbol($slot) ) {
    #   return ${ $meta->get_package_symbol($slot) };
    # }
    no strict 'refs';
    my $v = *{"${pkg}::${attribute}"}{SCALAR};
    if (defined ${$v}) {
     return ${$v};
    } else {
      foreach my $super ( $meta->linearized_isa ) {
        # tighter version of same after
        # my $super_meta = Moose::Meta::Class->initialize($super);
        my $v = ${"${super}::"}{$attribute} ? *{"${super}::${attribute}"}{SCALAR} : undef;
        if (defined ${$v}) {
          return ${$v};
        }
      }
    }
    return;
  };

  confess("Failed to create accessor: $@ ")
    unless ref $accessor eq 'CODE';

  my $meta = $class->Class::MOP::Object::meta();
  confess "${class}'s metaclass is not a Class::MOP::Class"
    unless $meta->isa('Class::MOP::Class');

  my $was_immutable = $meta->is_immutable;
  my %immutable_options = $meta->immutable_options;

  $meta->make_mutable if $was_immutable;

  my $alias = "_${attribute}_accessor";
  $meta->add_method($alias, $accessor);
  $meta->add_method($attribute, $accessor);

  $meta->make_immutable(%immutable_options) if $was_immutable;

  $class->$attribute($_[2]) if(@_ > 2);
  return $accessor;
}

1;

__END__


=head1 NAME

Catalyst::ClassData - Class data accessors

=head1 METHODS

=head2 mk_classdata $name, $optional_value

A moose-safe clone of L<Class::Data::Inheritable> that borrows some ideas from
L<Class::Accessor::Grouped>;

=head1 AUTHOR

=begin stopwords

Guillermo Roditi

=end stopwords

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
