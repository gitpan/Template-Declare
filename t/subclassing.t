use warnings;
use strict;

package Wifty::UI;
use base qw/Template::Declare/;
use Template::Declare::Tags;

template simple => sub {

    html {
        head {};
        body { show 'private-content'; };
        }

};

private template 'private-content' => sub {
    my $self = shift;
    with( id => 'body' ), div {
        outs('This is my content from'.$self);
    };
};



package Baseclass::UI;
use base qw/Template::Declare/;
use Template::Declare::Tags;
private template 'private-content' => sub {
    with( id => 'body' ), div {
        outs('This is baseclass content');
    };

};


package Childclass::UI;
use base qw/Template::Declare/;
use Template::Declare::Tags;
private template 'private-content' => sub {
    with( id => 'body' ), div {
        outs('This is child class content');
    };

};




package main;
use Template::Declare::Tags;
Template::Declare->init(roots => ['Baseclass::UI', 'Wifty::UI']);

use Test::More tests => 9;
require "t/utils.pl";

{
    local $Template::Declare::Tags::BUFFER;
    local $Template::Declare::Tags::self = 'Wifty::UI';
    my $simple =  Template::Declare::Tags::show('simple') ;
    like( $simple,  qr'This is my content' );
    like( $simple,  qr'Wifty::UI', '$self is correct in template block' );
    ok_lint($simple);
}


Template::Declare->init(
    roots => [ 'Baseclass::UI', 'Wifty::UI', 'Childclass::UI' ] );
{
    local $Template::Declare::Tags::BUFFER;
    my $simple = ( show('simple') );
    like( $simple, qr'This is child class content' );
    ok_lint($simple);
}

{
    local $Template::Declare::Tags::BUFFER;
    my $simple = ( show('does_not_exist') );
    unlike( $simple , qr'This is my content' );
    ok_lint($simple);
}
{
    local $Template::Declare::Tags::BUFFER;
    my $simple = ( show('private-content') );
    unlike( $simple , qr'This is my content', "Can't call private templates" );
    ok_lint($simple);
}


1;
