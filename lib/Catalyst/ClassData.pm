package Catalyst::ClassData;

use Moose::Role;
use Scalar::Util 'blessed';

sub mk_classdata {
  my ($class, $attribute) = @_;
  confess("mk_classdata() is a class method, not an object method")
    if blessed $class;

  my $slot = '$'.$attribute;
  my $accessor =  sub {
    if(@_ > 1){
      $_[0]->meta->add_package_symbol($slot, \  $_[1]);
      return $_[1];
    }
    foreach my $super ( $_[0], $_[0]->meta->linearized_isa ) {
      my $meta = $super->meta;
      if( $meta->has_package_symbol($slot) ){
        return $meta->get_package_symbol($slot);
      }
    }
    return;
  };
  my $accessor = eval $code;
  confess("Failed to create accessor: $@ \n $code \n")
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

#   my $code = ' sub {
#     if(@_ > 1){
#       $_[0]->meta->add_package_symbol(\''.$slot.'\', \  $_[1]);
#       return $_[1];
#     }
#     foreach my $super ( $_[0], $_[0]->meta->linearized_isa ) {
#       my $meta = $super->meta;
#       if( $meta->has_package_symbol(\''.$slot.'\') ){
#         return $meta->get_package_symbol(\''.$slot.'\');
#       }
#     }
#     return;
#   }';
#   my $accessor = eval $code;
