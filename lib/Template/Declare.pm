use warnings;
use strict;

package Template::Declare;

$Template::Declare::VERSION = "-1.00_01";

=head1 NAME

Template::Declare

=head1 DESCRIPTION

C<Template::Declare> is a prototype declarative code-based HTML
templating system. Yes. Another one. There are many others like it,
but this one is ours. It's designed to allow template libraries to be
composed, mixed in and inherited. The code isn't (yet) pretty nor is 
it in any way optimized. It's not well enough tested, either.

In the coming weeks, months and years, Template::Declare we will extend it
to support all the things we've designed it to do. 

=head1 BUGS

Crawling all over, baby. Be very, very careful. This code is so cutting edge, it can only be fashioned from carbon nanotubes.

The only real documentation is in t/trivial.t

=cut


sub has_template {
    my $pkg = shift;
    my $templatename = shift;

    my $callable = "_jifty_template_".$templatename;
    return $pkg->can($callable);

}

1;
