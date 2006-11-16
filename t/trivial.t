use warnings;
use strict;


package Wifty::UI;
use base qw/Template::Declare/;
use Template::Declare::Tags;
use Test::More;

template simple => sub {

html { 
    head { };
        body {
            show 'content';
        }
}

};

template content => sub {
        with( id => 'body' ), div {
            outs('This is my content');
        };

};


template wrapper => sub {
    my ( $title, $coderef) = (@_);
    outs('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">');
        with ( xmlns      => "http://www.w3.org/1999/xhtml", 'xml:lang' => "en"), 
    html {
        head {
            with ( 'http-equiv' => "content-type", 'content'    => "text/html; charset=utf-8"),
            meta { };
            with ( name    => "robots", content => "all"), meta { };
            title { outs($title) };
            };
        body {
            $coderef->(); 
        }
            
        }
};

template markup => sub {
    my $self = shift;

    show(
        'wrapper',
        'My page!',
        sub {

            with( id => 'syntax' ), div {
                div {
                    with(
                        href    => "#",
                        onclick =>
                            "Element.toggle('syntax_content');return(false);"
                        ),
                        a {
                        b {'Wiki Syntax Help'};
                        }
                };
                with( id => 'syntax_content' ), div {
                    h3   {'Phrase Emphasis'};
                    code {
                        b { '**bold**'; };
                        i {'_italic_'};
                    };

                    h3 {'Links'};

                    code {'Show me a [wiki page](WikiPage)'};
                    code {'An [example](http://url.com/ "Title")'};
                    h3   {'Headers'};
                    pre  {
                        code {
                            join( "\n",
                                '# Header 1',
                                '## Header 2',
                                '###### Header 6' );
                            }
                    };
                    h3  {'Lists'};
                    p   {'Ordered, without paragraphs:'};
                    pre {
                        code { join( "\n", '1.  Foo', '2.  Bar' ); };
                    };
                    p   {' Unordered, with paragraphs:'};
                    pre {
                        code {
                            join( "\n",
                                '*   A list item.',
                                'With multiple paragraphs.',
                                '*   Bar' );
                            }
                    };
                    h3 {'Code Spans'};

                    p {
                        code {'`&lt;code&gt;`'}
                            . 'spans are delimited by backticks.';
                    };

                    h3 {'Preformatted Code Blocks'};

                    p {
                        'Indent every line of a code block by at least 4 spaces.';
                    };

                    pre {
                        code {
                            'This is a normal paragraph.' . "\n\n" . "\n"
                                . '    This is a preformatted' . "\n"
                                . '    code block.';
                        };
                    };

                    h3 {'Horizontal Rules'};

                    p {
                        'Three or more dashes: ' . code {'---'};
                    };

                    address {
                        '(Thanks to <a href="http://daringfireball.net/projects/markdown/dingus">Daring Fireball</a>)';
                        }
                    }
            };
            script {
                qq{
   // javascript flyout by Eric Wilhelm
   // TODO use images for minimize/maximize button
   // Is there a way to add a callback?
   Element.toggle('syntax_content');
   };
            };
        }
    );
};

package Template::Declare::Tags;

use Test::More qw/no_plan/;
use HTML::Lint;

our $self;
local $self = {};
bless $self, 'Wifty::UI';
{
local $Template::Declare::Tags::BUFFER;
my $simple =(show('simple'));
ok($simple =~ 'This is my content');
#diag ($simple);
ok_lint($simple);
}
{local $Template::Declare::Tags::BUFFER;
my $out =  (show('markup'));
#diag($out);
my @lines = split("\n",$out);

ok($out =~ /Fireball/, "We found fireball in the output");
my $count = grep { /Fireball/} @lines;
is($count, 1, "Only found one");
ok_lint($out);

}
sub ok_lint {
    my $html = shift;

    my $lint = HTML::Lint->new;

    $lint->parse($html);
    is( $lint->errors, 0, "Lint checked clean" );
    foreach my $error ( $lint->errors ) {
        diag( $error->as_string );
    }

}


1;
