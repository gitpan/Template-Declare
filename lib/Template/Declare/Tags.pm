use warnings;
use strict;

package Template::Declare::Tags;
use vars qw/@EXPORT @EXPORT_OK $self/;
use base 'Exporter';
@EXPORT_OK = (qw(with));
@EXPORT = (qw(with template private show outs  outs in_isolation));

our $DEPTH = 0;
our %ATTRIBUTES = ();
our $BUFFER = '';

sub outs { $BUFFER .= join('',grep { defined } @_); return ''; }
sub template ($$) {
    my $templatename = shift;
    my $coderef = shift;
    no strict 'refs';
    *{(caller(0))[0]."::_jifty_template_$templatename"} = sub { my $self = shift; $coderef->(@_) } ;

}
sub private ($){}

sub install_tag {
    my $tag = shift;
    { no strict 'refs';
      *{$tag} = sub (&) {local *__ANON__ = $tag; _tag(@_)};
    }
      push @EXPORT_OK, $tag;
      push @EXPORT, $tag;
}


our %TAGS = ( html => {}, head => {}, title => {}, meta => {}, body => {}, p => {}, hr => {}, br => {}, ul => {}, dl => {}, dt=> {}, dd => {}, ol => {}, li => {}, b => {}, i => {}, em => {}, div => {}, span => {}, form => {}, input => {}, textarea => {}, select => {}, option => {}, a => {}, pre => {}, code => {}, address => {}, iframe => {}, script => {}, h1 => {}, h2=> {}, h3 => {}, h4 => {}, h5 => {}, ); install_tag($_) for(keys %TAGS);




sub with (@) {
    %ATTRIBUTES = ();
    while (@_) {
        my $key = shift || '';
        my $val = shift || '';
        $ATTRIBUTES{$key} = $val;
    }
}

sub _tag {
    my $code = shift;
    my ($package,   $filename, $line,       $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints,      $bitmask
        )
        = caller(1);

    # This is the hash of attributes filled in by attr() calls in the code;

    my $tag = $subroutine;
    $tag =~ s/^.*\:\://;
    $BUFFER .= "\n" . ( " " x $DEPTH ) . "<$tag"
        . join( '',
        map { qq{ $_="} . ( $ATTRIBUTES{$_} || '' ) . qq{"} }
            keys %ATTRIBUTES );
    %ATTRIBUTES = ();

    my $buf;
    {
        local $BUFFER = '';
        local $DEPTH  = $DEPTH + 1;
        my $last = $code->() || '';

        $buf = $BUFFER;

# We concatenate "" to force scalarization when $last or $BUFFER is solely a Jifty::Web::Link
        $buf .= $last unless ($BUFFER);    # HACK WRONG;
    }

    # default to <tag/> rather than <tag></tag> if there's no content
    if ($buf) {
        $BUFFER .= ( ">" . $buf );
        $BUFFER .= "\n" . ( " " x $DEPTH ) if ( $buf =~ /\n/ );
        $BUFFER .= "</$tag>";
    } else {
        $BUFFER .= "/>";
    }
    return '';
}

=head2 show [$class or $object] templatename

show can either be called with a template name or a package/object and 
a template.  (It's both functional and OO.)

Displays that template, if it exists. 


=cut

sub show {
    $self = shift if ( $_[0]->isa('Template::Declare') );
    my $templatename = shift;
    my $buf;
    {
        local $BUFFER = '';
        my $callable = "_jifty_template_" . $templatename;

        # may want to just use the return value of has_template eventuall
        my $ret = $self->$callable(@_) if $self->has_template($templatename);
        $buf = $BUFFER;
    }
    $BUFFER .= $buf;
    return $buf;
}

1;
