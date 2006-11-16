use warnings; use strict;
use vars qw'%ATTRIBUTES $BUFFER $DEPTH';
sub html (&) { _element(@_); }
sub head (&) { _element(@_); }
sub body (&) { _element(@_); }
sub p (&)    { _element(@_); }
sub br (&)   { _element(@_); }
sub ul (&)   { _element(@_); }
sub li (&)   { _element(@_); }
sub dl (&)   { _element(@_); }
sub ol (&)   { _element(@_); }
sub b (&)    { _element(@_); }
sub i (&)    { _element(@_); }
sub em (&)   { _element(@_); }
sub div (&)  { _element(@_); }
sub span (&) { _element(@_); }
sub attr ($$) {my ($key,$val)=(@_); $ATTRIBUTES{$key} = $val; }

sub _element {
    my $code = shift;
    my ($package,   $filename, $line,       $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints,      $bitmask
        )
        = caller(1);

    local %ATTRIBUTES = ();

    my $tag = $subroutine;
    $tag =~ s/^$package\:\://;

my $buf;
    {
    local $BUFFER = '';
    local $DEPTH = $DEPTH +1;

    $code->();
     $buf = $BUFFER;
}
    $BUFFER .= "\n".(" " x $DEPTH). "<$tag"
        . join( '', map {qq{ $_="$ATTRIBUTES{$_}"}} keys %ATTRIBUTES ) . ">"
        . ($buf ? ($buf . "\n" . (" " x $DEPTH) ) : '')
        ."</$tag>";

    return $BUFFER;
}


print html {

    head {
        attr id   => 5;
        attr name => "I hate you";
    };
    body {
        for ( 1 .. 5 ) {
            span { attr class => "bozo"; 'yyy' };
        }
        attr bgcolor => "#ffffff";
        p {'xxx'};
        }
};


