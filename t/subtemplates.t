use warnings;
use strict;


package Wifty::UI;
use base qw/Template::Declare/;
use Template::Declare::Tags;
use Test::More tests => 4;
require "t/utils.pl";

template simple => sub {

html { 
    head { };
        body {
            show 'my/content'
        }
}

};

template 'my/content' => sub {
        div { attr { id => 'body' }
            outs('This is my content')
        }

};


Template::Declare->init(roots => ['Wifty::UI']);


{
my $simple =(show('my/content'));
ok($simple =~ 'This is my content');
#diag ($simple);
ok_lint($simple);
}
{
my $simple =(show('simple'));
ok($simple =~ 'This is my content');
#diag ($simple);
ok_lint($simple);
}


1;
