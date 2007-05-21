use warnings;
use strict;

package Template::Declare::Buffer;
use base 'Class::Accessor';

__PACKAGE__->mk_accessors('data');

sub append {
    my $self    = shift;
    my $content = shift;

    no warnings 'uninitialized';
    $self->data( $self->data . $content );
}

sub clear {
    my $self = shift;
    $self->data('');
}

1;
