use 5.006;
use warnings;
use strict;

package Template::Declare::Tags;
use Template::Declare;
use vars qw/@EXPORT @EXPORT_OK $PRIVATE $self/;
use base 'Exporter';
use Carp;

@EXPORT
    = qw( with template private show show_page attr outs outs_raw in_isolation $self under get_current_attr smart_tag_wrapper );
push @EXPORT, qw(Tr td );   # these two warns the user to use row/cell instead

our %ATTRIBUTES       = ();
our %ELEMENT_ID_CACHE = ();
our $TAG_NEST_DEPTH            = 0;
our @TEMPLATE_STACK;

=head1 NAME

Template::Declare::Tags

=head1 METHODS

=head2 template TEMPLATENAME => sub { 'Implementation' };

C<template> declares a template in the current package. You can pass
any url-legal characters in the template name. C<Template::Declare>
will encode the template as a perl subroutine and stash it to be called
with C<show()>.

(Did you know that you can have characters like ":" and "/" in your Perl
subroutine names? The easy way to get at them is with "can").


=cut

sub template ($$) {
    my $template_name  = shift;
    my $coderef        = shift;
    my $template_class = ( caller(0) )[0];

    no warnings qw( uninitialized redefine );

    # template "foo" ==> CallerPkg::_jifty_template_foo;
    # template "foo/bar" ==> CallerPkg::_jifty_template_foo/bar;
    my $codesub = sub {
        local $self = shift || $self || $template_class;

        #local $self = $template_class unless $self;
        &$coderef($self,@_);
    };

    if (wantarray) {

# We're being called by something like private that doesn't want us to register ourselves
        return ( $template_class, $template_name, $codesub );
    } else {

       # We've been called in a void context and should register this template
        Template::Declare::register_template( $template_class, $template_name,
            $codesub );
    }

}

=head2 private template TEMPLATENAME => sub { 'Implementation' };

C<private> declares that a template isn't available to be called directly from client code.

=cut

sub private (@) {
    my $class   = shift;
    my $subname = shift;
    my $code    = shift;
    Template::Declare::register_private_template( $class, $subname, $code );
}

=head2 attr HASH

With C<attr>, you can specify attributes for HTML tags.


Example:

 p { attr { class => 'greeting text',
            id => 'welcome' };

    'This is a welcoming paragraph';

 }


=cut

sub attr (&;@) {
    my $code = shift;
    my @rv   = $code->();
    while ( my ( $field, $val ) = splice( @rv, 0, 2 ) ) {

        # only defined whle in a tag context
        append_attr( $field, $val );
    }
    return @_;
}

=head2 outs STUFF

C<outs> HTML-encodes its arguments and appends them to C<Template::Declare>'s output buffer.


=cut

#sub outs { outs_raw( map { _escape_html($_); } grep {defined} @_ ); }

=head2 outs_raw STUFF

C<outs_raw> appends its arguments to C<Template::Declare>'s output buffer without doing any HTML escaping.

=cut

#sub outs_raw { Template::Declare->buffer->append( join( '', grep {defined} @_ )); return ''; }

sub outs     { _outs( 0, @_ ); }
sub outs_raw { _outs( 1, @_ ); }

sub _outs {
    my $raw     = shift;
    my @phrases = (@_);
    my $buf;
    Template::Declare->new_buffer_frame;

    foreach my $item ( grep {defined} @phrases ) {

        Template::Declare->new_buffer_frame;
        my $returned =
            ref($item) eq 'CODE'
            ? $item->()
            : ( $raw ? $item : _escape_html($item) ) || '';
        my $content = Template::Declare->buffer->data || '';
        Template::Declare->end_buffer_frame;
        Template::Declare->buffer->append( $content . $returned );
    }

    $buf = Template::Declare->buffer->data || '';
    Template::Declare->end_buffer_frame;
    if ( defined wantarray and not wantarray ) {
        return $buf;
    } else {
        Template::Declare->buffer->append($buf);

    }
    return '';
}

=head2 get_current_attr 

Help! I'm deprecated/

=cut 

sub get_current_attr ($) {
    $ATTRIBUTES{ $_[0] };
}

our %TagAlternateSpelling = (
    tr   => 'row',
    td   => 'cell',
    base =>
        '',    # Currently 'base' has no alternate spellings; simply ignore it
);

=head2 install_tag TAGNAME

Sets up TAGNAME as a tag that can be used in user templates.

Out of the box, C<Template::Declare> installs  the :html2 :html3 :html4 :netscape and
:form tagsets from CGI.pm.  Patches to make this configurable or use HTML::TagSet would be great.


=cut

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
            my $sub   = sub {
                local $self     = $_self;
                local *__ANON__ = $tag;
                _tag(@__);
            };
            bless $sub, 'Template::Declare::Tag';
            return $sub;
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

=head2 with

C<with> is an alternative way to specify attributes for a tag:

    with ( id => 'greeting'), 
        p { 'Hello, World wide web' };


The standard way to do this is:

    p { attr { id => 'greeting' };
        'Hello, World wide web' };


=cut

sub with (@) {
    %ATTRIBUTES = ();
    while ( my ( $key, $val ) = splice( @_, 0, 2 ) ) {
        no warnings 'uninitialized';
        $ATTRIBUTES{$key} = $val;

        if ( lc($key) eq 'id' ) {
            if ( $ELEMENT_ID_CACHE{$val}++ ) {
                warn
                    "HTML appears to contain illegal duplicate element id: $val";
            }
        }

    }
    wantarray ? () : '';
}

=head2 smart_tag_wrapper

  # create a tag that has access to the arguments set with with.
  sub sample_smart_tag (&) {
      my $code = shift;

      smart_tag_wrapper {
          my %args = @_; # set using 'with'
          outs( 'keys: ' . join( ', ', sort keys %args) . "\n" );
          $code->();
      };
  }
  
  # use it
  with ( foo => 'bar', baz => 'bundy' ),
    sample_smart_tag {
      outs( "Hello, World!\n" );
    };

  # output would be
  keys: baz, foo
  Hello, World!

The smart tag wrapper allows you to create code that has access to the arguments
set using 'with', it passes them in to the wrapped code in C<@_>. It also takes
care of putting the output in the right place and tidying up after itself.

=cut

sub smart_tag_wrapper (&) {
    my $coderef = shift;
    my $buf     = "\n";

    Template::Declare->new_buffer_frame;

    my $last = join '',    #
        map { ref($_) ? $_ : _escape_html($_) }    #
        $coderef->(%ATTRIBUTES);

    %ATTRIBUTES = ();                              # prevent leakage

    if ( length( Template::Declare->buffer->data ) ) {

        # We concatenate to force scalarization when $last or
        # $Template::Declare->buffer is solely a Jifty::Web::Link
        $buf .= Template::Declare->buffer->data;
    } elsif ( length $last ) {
        $buf .= $last;
    }

    Template::Declare->end_buffer_frame;
    Template::Declare->buffer->append($buf);

    return '';
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

    my $buf = "\n" . ( " " x $TAG_NEST_DEPTH ) . "<$tag"
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

            $buf .= ' ' . $field . q{="} . _escape_html($val) . q{"};
            wantarray ? () : '';
        };

        local $TAG_NEST_DEPTH = $TAG_NEST_DEPTH + 1;
        %ATTRIBUTES = ();
        Template::Declare->new_buffer_frame;
        my $last = join '', map { ref($_) ? $_ : _escape_html($_) } $code->();

        if ( length( Template::Declare->buffer->data ) ) {

# We concatenate to force scalarization when $last or $Template::Declare->buffer is solely a Jifty::Web::Link
            $buf .= '>' . Template::Declare->buffer->data;
            $had_content = 1;
        } elsif ( length $last ) {
            $buf .= '>' . $last;
            $had_content = 1;
        } else {
            $had_content = 0;
        }

        Template::Declare->end_buffer_frame;

    }

    if ($had_content) {
        $buf .= "\n" . ( " " x $TAG_NEST_DEPTH ) if ( $buf =~ /\>$/ );
        $buf .= "</$tag>";
    } elsif ( $tag
        =~ m{\A(?: base | meta | link | hr | br | param | img | area | input | col )\z}x
        )
    {

        # XXX TODO: This should come out of HTML::Tagset
        # EMPTY tags can close themselves.
        $buf .= " />";
    } else {

        # Otherwise we supply a closing tag.
        $buf .= "></$tag>";
    }

    Template::Declare->buffer->append($buf);
    return ( ref($more_code) && $more_code->isa('CODE') )
        ? $more_code->()
        : '';
}

=head2 show [$template_name or $template_coderef] 

C<show> displays templates. 

Do not call templates with arguments. That's not supported.

XXX TODO: This makes jesse cry. Audrey/cl: sanity check?

C<show> can either be called with a template name or a package/object
and a template.  (It's both functional and OO.)

If called from within a Template::Declare subclass, then private
templates are accessible and visible. If called from something that
isn't a Template::Declare, only public templates wil be visible.

From the outside world, users can either call
C<Template::Declare->show()> or C<Template::Declare::tags::show()> to
render a publicly visible template.

"private" templates may only be called from within the
C<Template::Declare> package.

=cut

sub show {
    my $template = shift;
    my $args  = \@_;
    my $data;

    # if we're inside a template, we should show private templates
    if ( caller->isa('Template::Declare') ) {
       _show_template( $template, 1, $args );
        return Template::Declare->buffer->data;
    } else {
        show_page( $template, $args);
    }

}



sub show_page {
    my $template        = shift;
    my $args = \@_;
    my $INSIDE_TEMPLATE = 0;

    # if we're inside a template, we should show private templates
    Template::Declare->new_buffer_frame;
    _show_template( $template, 0, $args );
    my $data = Template::Declare->buffer->data;
    Template::Declare->end_buffer_frame;
    %ELEMENT_ID_CACHE = ();    # We're done. we can clear the cache
   if (not defined wantarray()) {  
    
    Template::Declare->buffer->append($data);
    return undef;
     } else {
    return $data;

     }
}

sub _resolve_relative_template_path {
    my $template = shift;

    return $template unless ($template =~ '^\.');
    my $parent = $TEMPLATE_STACK[-1];
  
    my @parent = split('/',$parent);
    my @template = split('/',$template);

    if ($template[0] eq '.') {
        shift @template; # get rid of the . 
        pop @parent; # Get rid of the parent's tempalte name
        return (join('/', @parent, @template));
    }



}

sub _show_template {
    my $template        = shift;
    my $inside_template = shift;
    my $args = shift;
    local @TEMPLATE_STACK  = @TEMPLATE_STACK;
    $template = _resolve_relative_template_path($template);
    push @TEMPLATE_STACK, $template;


    my $callable =
        ( ref($template) && $template->isa('Template::Declare::Tag') )
        ? $template
        : Template::Declare->resolve_template( $template, $inside_template );

    # If the template was not found let the user know.
    unless ($callable) {
        my $msg = "The template '$template' could not be found";
        $msg .= " (it might be private)" if !$inside_template;
        carp $msg;
        return '';
    }

    Template::Declare->new_buffer_frame;
    &$callable($self, @$args);
    my $content = Template::Declare->buffer->data;
    Template::Declare->end_buffer_frame;
    Template::Declare->buffer->append($content);
}

sub _escape_html {
    my $val = shift;
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
    die
        "Tr {...} and td {...} are invalid; use row {...} and cell {...} instead.";
}

=head2 td

Template::Declare::Tags uses C<row> and C<cell> for table definitions rather than C<tr> and C<td>. 
(C<tr> is reserved by the perl interpreter for the operator of that name. We can't override it.)

=cut

sub td (&) {
    die
        "Tr {...} and td {...} are invalid; use row {...} and cell {...} instead.";
}

=head1 SEE ALSO

L<Template::Declare>

=head1 AUTHOR

Jesse Vincent <jesse@bestpractical.com>

=head1 COPYRIGHT

Copyright 2006-2007 Best Practical Solutions, LLC

=cut

package Template::Declare::Tag;

use overload '""' => \&stringify;

sub stringify {
    my $self = shift;

    if ( defined wantarray ) {
        Template::Declare->new_buffer_frame;
        my $returned = $self->();
        my $content  = Template::Declare->buffer->data();
        Template::Declare->end_buffer_frame;
        return ( $content . $returned );
    } else {

        return $self->();
    }
}

1;
