package Catalyst::ClassData;

use Moose::Role;
use Class::MOP;
use Scalar::Util 'blessed';

sub mk_classdata {
  my ($class, $attribute) = @_;
  confess("mk_classdata() is a class method, not an object method")
    if blessed $class;

  my $slot = '$'.$attribute;
  my $accessor =  sub {
    my $meta = $_[0]->meta;
    if(@_ > 1){
      $meta->add_package_symbol($slot, \ $_[1]);
      return $_[1];
    }

    if( $meta->has_package_symbol($slot) ){
      return ${ $meta->get_package_symbol($slot) };
    } else {
      foreach my $super ( $meta->linearized_isa ) {
        my $super_meta = Moose::Meta::Class->initialize($super);
        if( $super_meta->has_package_symbol($slot) ){
          return ${ $super_meta->get_package_symbol($slot) };
        }
      }
    }
    return;
  };

  confess("Failed to create accessor: $@ ")
    unless ref $accessor eq 'CODE';

  my $meta = $class->meta;
  my $alias = "_${attribute}_accessor";
  $meta->add_method($alias, $accessor);
  $meta->add_method($attribute, $accessor);
  $class->$attribute($_[2]) if(@_ > 2);
  return $accessor;
}

1;

__END__


=head1 NAME

Catalyst::ClassData - Class data acessors

=head1 METHODS

=head2 mk_classdata $name, $optional_value

A moose-safe clone of L<Class::Data::Inheritable> that borrows some ideas from
L<Class::Accessor::Grouped>;

=head1 AUTHOR

Guillermo Roditi

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
