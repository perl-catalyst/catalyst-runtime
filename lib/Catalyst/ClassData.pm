package Catalyst::ClassData;

use Moose::Role;
use Scalar::Util 'blessed';

sub mk_classdata {
  my ($declaredclass, $attribute, $data) = @_;
  confess("mk_classdata() is a class method, not an object method")
    if ref $declaredclass;

  my $accessor = sub {
    my $wantclass = blessed($_[0]) || $_[0];

    return $wantclass->mk_classdata($attribute)->(@_)
      if @_>1 && $wantclass ne $declaredclass;

    $data = $_[1] if @_>1;
    return $data;
  };

  my $alias = "_${attribute}_accessor";
  $declaredclass->meta->add_method($alias, $accessor);
  $declaredclass->meta->add_method($attribute, $accessor);
  return $accessor;
}

1;

__END__
