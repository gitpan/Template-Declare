use warnings;
use strict;


package Wifty::UI;
use base qw/Template::Declare/;
use Template::Declare::Tags;
use Test::More tests => 8;


template content => sub { div { outs('This is my <b>content</b>') } };
template content_2 => sub { div { 'This is my <b>content</b>' } };
template content_3 => sub { div { p{ 'This is my <b>content</b>'}}; };
template content_4 => sub { div { p{ outs('This is my '); b{ 'content'}}}; };

package Template::Declare::Tags;

use Test::More;
require "t/utils.pl";

our $self;
local $self = {};
bless $self, 'Wifty::UI';

Template::Declare->init( roots => ['Wifty::UI']);


for (qw(content content_2 content_3 ) ){
{
local $Template::Declare::Tags::BUFFER;
my $simple =(show($_));
ok($simple =~ 'This is my &lt;b&gt;content');
ok_lint($simple);
}
}
for (qw(content_4) ){
{
local $Template::Declare::Tags::BUFFER;
my $simple =(show($_));
ok($simple =~ m/This is my\s*<b>\s*content/);
ok_lint($simple);
}
}


1;
