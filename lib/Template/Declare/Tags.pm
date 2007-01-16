use warnings;
use strict;

package Template::Declare::Tags;
use Template::Declare;
use vars qw/@EXPORT @EXPORT_OK $PRIVATE $self/;
use base 'Exporter';
use Carp;

@EXPORT = qw( with template private show get_current_attr attr outs outs_raw in_isolation $self under);
push @EXPORT, qw(Tr td );    # these two warns the user to use row/cell instead

our %ATTRIBUTES = ();
our $BUFFER     = '';
our $DEPTH      = 0;

sub attr (&;$) {
    my ( $code, $out ) = @_;
    my @rv = $code->();
    while ( my ( $field, $val ) = splice( @rv, 0, 2 ) ) {

        # only defined whle in a tag context
        append_attr( $field, $val );
    }
    $out;
}

sub outs_raw {
    $BUFFER .= join( '', grep {defined} @_ );
    return '';
}

sub outs {
    $BUFFER .= join( '', map { _escape_utf8($_); } grep {defined} @_ );
    return '';
}

sub template ($$) {
    my $template_name  = shift;
    my $coderef        = shift;
    my $template_class = ( caller(0) )[0];

    no warnings qw( uninitialized redefine );

    # template "foo" ==> CallerPkg::_jifty_template_foo;
    # template "foo/bar" ==> CallerPkg::_jifty_template_foo/bar;
    my $codesub = sub { my $self = shift if ($_[0]); &$coderef($self) };

    if (wantarray) { 
        # We're being called by something like private that doesn't want us to register ourselves
        return ( $template_class, $template_name, $codesub );
    } else {
        # We've been called in a void context and should register this template
        Template::Declare::register_template( $template_class, $template_name, $codesub );
    }

}

sub private (@) {
    my $class   = shift;
    my $subname = shift;
    my $code    = shift;
    Template::Declare::register_private_template( $class, $subname, $code );
}

sub get_current_attr ($) {
    $ATTRIBUTES{ $_[0] };
}

our %TagAlternateSpelling = (
    tr   => 'row',
    td   => 'cell',
    base =>
        '',    # Currently 'base' has no alternate spellings; simply ignore it
);

sub install_tag {
    my $tag  = lc( $_[0] );
    my $name = $tag;

    if ( exists( $TagAlternateSpelling{$tag} ) ) {
        $name = $TagAlternateSpelling{$tag} or return;
    }

    push @EXPORT, $name;

    no strict 'refs';
    no warnings 'redefine';
    *$name = sub (&;$) {
        local *__ANON__ = $tag;
        if ( defined wantarray and not wantarray ) {

            # Scalar context - return a coderef that represents ourselves.
            my @__    = @_;
            my $_self = $self;
            sub {
                local $self     = $_self;
                local *__ANON__ = $tag;
                _tag(@__);
            };
        } else {
            _tag(@_);
        }
    };
}

use CGI ();
our %TAGS = (
    map { $_ => +{} }
        map {@$_} @CGI::EXPORT_TAGS{qw/:html2 :html3 :html4 :netscape :form/}
);
install_tag($_) for keys %TAGS;

sub with (@) {
    %ATTRIBUTES = ();
    while ( my ( $key, $val ) = splice( @_, 0, 2 ) ) {
        no warnings 'uninitialized';
        $ATTRIBUTES{$key} = $val;
    }
    wantarray ? () : '';
}

sub _tag {
    my $code      = shift;
    my $more_code = shift;
    my ($package,   $filename, $line,       $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints,      $bitmask
        )
        = caller(1);

    # This is the hash of attributes filled in by attr() calls in the code;

    my $tag = $subroutine;
    $tag =~ s/^.*\:\://;

    my $buf = "\n" . ( " " x $DEPTH ) . "<$tag"
        . join( '',
        map { qq{ $_="} . ( $ATTRIBUTES{$_} || '' ) . qq{"} }
            sort keys %ATTRIBUTES );

    my $had_content = 0;

    {
        no warnings qw( uninitialized redefine once );

        local *is::AUTOLOAD = sub {
            shift;

            my $field = our $AUTOLOAD;
            $field =~ s/.*:://;

            $field =~ s/__/:/g;   # xml__lang  is 'foo' ====> xml:lang="foo"
            $field =~ s/_/-/g;    # http_equiv is 'bar' ====> http-equiv="bar"

            # Squash empty values, but not '0' values
            my $val = join( ' ', grep { defined $_ && $_ ne '' } @_ );

            append_attr( $field, $val );
        };

        local *append_attr = sub {
            my $field = shift;
            my $val   = shift;

            $buf .= ' '. $field .q{="} .  _escape_utf8($val) .q{"};
            wantarray ? () : '';
        };

        local $BUFFER;
        local $DEPTH = $DEPTH + 1;
        %ATTRIBUTES = ();
        my $last = join '', map { ref($_) ? $_ : _escape_utf8($_) } $code->();

        if ( length($BUFFER) ) {

# We concatenate to force scalarization when $last or $BUFFER is solely a Jifty::Web::Link
            $buf .= '>' . $BUFFER;
            $had_content = 1;
        } elsif ( length $last ) {
            $buf .= '>' . $last;
            $had_content = 1;
        } else {
            $had_content = 0;
        }

    }

    if ($had_content) {
        $BUFFER .= $buf;
        $BUFFER .= "\n" . ( " " x $DEPTH ) if ( $buf =~ /\n/ );
        $BUFFER .= "</$tag>";
    } elsif ( $tag =~ m{\A(?: base | meta | link | hr | br | param | img | area | input | col )\z}x) {
        # XXX TODO: This should come out of HTML::Tagset
        # EMPTY tags can close themselves.
        $BUFFER .= $buf . " />";
    } else {

        # Otherwise we supply a closing tag.
        $BUFFER .= $buf . "></$tag>";
    }

    return $more_code ? $more_code->() : '';
}

=head2 show [$class or $object] [$template_name or $template_coderef] 

C<show> displays templates. 

Do not call templates with arguments. That's not supported. 
XXX TODO: This makes jesse cry. Audrey/cl: sanity check?


C<show> can either be called with a template name or a package/object and 
a template.  (It's both functional and OO.)


If called from within a Template::Declare subclass, then private
templates are accessible and visible. If called from something that
isn't a Template::Declare, only public templates wil be visible.

=cut

sub show {
    my $template = shift;

    my $INSIDE_TEMPLATE = 0;

    # if we're inside a template, we should show private templates
    if ( caller()->isa('Template::Declare') ) { $INSIDE_TEMPLATE = 1; }
    my $callable =
        ref($template) eq 'CODE'
        ? $template
        : Template::Declare->has_template( $template, $INSIDE_TEMPLATE );

    return '' unless ($callable);

    my $buf = '';
    {
        local $BUFFER = '';
        &$callable($self);
        $buf = $BUFFER;
    }

    $BUFFER .= $buf;
    return $buf;
}

sub _escape_utf8 {
    my $val = shift;
    use bytes;
    no warnings 'uninitialized';
    $val =~ s/&/&#38;/g;
    $val =~ s/</&lt;/g;
    $val =~ s/>/&gt;/g;
    $val =~ s/\(/&#40;/g;
    $val =~ s/\)/&#41;/g;
    $val =~ s/"/&#34;/g;
    $val =~ s/'/&#39;/g;
    return $val;
}

=head2 import 'Package' under 'path'

Import the templates from C<Package> into the subpath 'path' of the current package, clobbering any
of your own package's templates that you'd already defined.

=cut

=head2 under

C<under> is a helper function for the "import" semantic sugar.

=cut

sub under ($) { return shift }

=head2 Tr

Template::Declare::Tags uses C<row> and C<cell> for table definitions rather than C<tr> and C<td>. 
(C<tr> is reserved by the perl interpreter for the operator of that name. We can't override it.)

=cut

sub Tr (&) {
    die "Tr {...} and td {...} are invalid; use row {...} and cell {...} instead.";
}

=head2 td

Template::Declare::Tags uses C<row> and C<cell> for table definitions rather than C<tr> and C<td>. 
(C<tr> is reserved by the perl interpreter for the operator of that name. We can't override it.)

=cut

sub td (&) {
    die "Tr {...} and td {...} are invalid; use row {...} and cell {...} instead.";
}

1;
