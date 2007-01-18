use warnings;
use strict;
use Carp;

package Template::Declare;

$Template::Declare::VERSION = "0.02";

use base 'Class::Data::Inheritable';
__PACKAGE__->mk_classdata('roots');
__PACKAGE__->mk_classdata('aliases');
__PACKAGE__->mk_classdata('alias_prefixes');
__PACKAGE__->mk_classdata('templates');
__PACKAGE__->mk_classdata('private_templates');


__PACKAGE__->roots([]);
__PACKAGE__->aliases([]);
__PACKAGE__->alias_prefixes({});
__PACKAGE__->templates({});
__PACKAGE__->private_templates({});



=head1 NAME

Template::Declare - Perlish declarative templates

=head1 SYNOPSIS

C<Template::Declare> is a pure-perl declarative HTML templating system. 

Yes.  Another one. There are many others like it, but this one is ours.

A few key features and buzzwords

=over

=item All templates are 100% pure perl code

=item Simple declarative syntax

=item No angle brackets

=item Mixins

=item Inheritance

=item Public and private templates

=back


=head1 USAGE


=head2 Basic usage

 package MyApp::Templates;
 use Template::Declare::Tags;
 use base 'Template::Declare';

 template simple => sub {
    html {
        head {}
        body {
            p {'Hello, world wide web!'};
            }
        }
 };

 package main;
 use Template::Declare;
 Template::Declare->init( roots => ['MyApp::Templates']);
 print Template::Declare->show( 'simple');

 # Output:
 #
 #
 # <html>
 #  <head></head>
 #  <body>
 #   <p>Hello, world wide web!
 #   </p>
 #  </body>
 # </html>


=head2 A slightly more advanced example

In this example, we'll show off how to set attributes on HTML tags, how to call other templates and how to declare a I<private> template that can't be called directly.

 package MyApp::Templates;
 use Template::Declare::Tags;
 use base 'Template::Declare';

 private template 'header' => sub {
        head {
            title { 'This is a webpage'};
            meta { attr { generator => "This is not your father's frontpage"}}
        }
 };

 template simple => sub {
    html {
        show('header');
        body {
            p { attr { class => 'greeting'};
                'Hello, world wide web!'};
            }
        }
 };

 package main;
 use Template::Declare;
 Template::Declare->init( roots => ['MyApp::Templates']);
 print Template::Declare->show( 'simple');

 # Output:
 #
 #  <html>
 #  <head>
 #   <title>This is a webpage
 #   </title>
 #   <meta generator="This is not your father&#39;s frontpage" />
 #  </head>
 #  <body>
 #   <p class="greeting">Hello, world wide web!
 #   </p>
 #  </body>
 # </html>
 

=head2 Multiple template roots (search paths)

=head2 Inheritance

=head2 Aliasing

=head1 METHODS

=head2 init

This I<class method> initializes the C<Template::Declare> system.

=over

=item roots

=back

=cut 

sub init {
    my $class = shift;
    my %args = (@_);

    if ($args{'roots'}) {
        $class->roots($args{'roots'});
    }

}

=head2 show TEMPLATE_NAME

Call C<show> with a C<template_name> and C<Template::Declare> will render that template and return the content as a scalar.

=cut

sub show {
    my $class = shift;
    my $template = shift;
    Template::Declare::Tags::show($template);

}

=head2 alias

 alias Some::Clever::Mixin under '/mixin';

=cut

sub alias {
    my $alias_into      = caller(0);
    my $mixin = shift;
    my $prepend_path     = shift;

    push @{$alias_into->aliases()}, $mixin ;
    $alias_into->alias_prefixes()->{$mixin} =  $prepend_path;

}


=head2 import


 import Wifty::UI::something under '/something';


=cut


sub import {
    return undef if $_[0] eq 'Template::Declare';
    my $import_into      = caller(0);
    my $import_from_base = shift;
    my $prepend_path     = shift;

    my @packages;
    {
        no strict 'refs';
        @packages = ( @{ $import_from_base . "::ISA" }, $import_from_base );
    }
    foreach my $import_from (@packages) {
        foreach my $template_name (
            @{ __PACKAGE__->templates()->{$import_from} } ) {
            $import_into->register_template(
                $prepend_path . "/" . $template_name,
                $import_from->_find_template_sub(
                    _template_name_to_sub($template_name)
                )
            );
        }
        foreach my $template_name (
            @{ __PACKAGE__->private_templates()->{$import_from} } ) {
            my $code = $import_from->_find_template_sub(
                _template_name_to_private_sub($template_name) );
            $import_into->register_private_template(
                $prepend_path . "/" . $template_name, $code );
        }
    }

}


=head2 has_template PACKAGE TEMPLATE_NAME SHOW_PRIVATE

Takes a package, template name and a boolean. The boolean determines whether to show private templates.

Returns a reference to the template's code if found. Otherwise, 
returns undef.

=cut

sub has_template {
    # When using Template::Declare->has_template, find in all
    # registered namespaces.
    goto \&resolve_template if $_[0] eq 'Template::Declare';

    # Otherwise find only in specific package
    my $pkg           = shift;
    my $template_name = shift;
    my $show_private  = 0 || shift;

    if ( my $coderef
        = $pkg->_find_template_sub(
            _template_name_to_sub($template_name) ) ) {
        return $coderef;
    }
    elsif (
        $show_private
        and $coderef = $pkg->_find_template_sub(
            _template_name_to_private_sub($template_name)
        ) ) {
        return $coderef;
    }

    return undef;
}

=head2 resolve_template TEMPLATE_PATH INCLUDE_PRIVATE_TEMPLATES

Turns a template path (C<TEMPLATE_PATH>) into a C<CODEREF>.  If the
boolean C<INCLUDE_PRIVATE_TEMPLATES> is true, resolves private template
in addition to public ones.

First it looks through all the valid Template::Declare roots. For each
root, it looks to see if the root has a template called $template_name
directly (or via an C<import> statement). Then it looks to see if there
are any L</alias>ed paths for the root with prefixes that match the
template we're looking for.

=cut


sub resolve_template {
    my $self          = shift;
    my $template_name = shift;
    my $show_private  = shift || 0;

    foreach my $package ( reverse @{ Template::Declare->roots } ) {
        if ( my $coderef = $package->has_template( $template_name, $show_private ) ) {
            return $coderef;
        }

        foreach my $alias_class ( @{ $package->aliases } ) {
            my $alias_prefix = $package->alias_prefixes()->{$alias_class};
            $template_name = "/$template_name";
            if ( $template_name =~ m{$alias_prefix/(.*)$} ) {
                my $dispatch_to_template = $1;
                if (my $coderef = $alias_class->has_template( $dispatch_to_template, $show_private)) {
                    # We're going to force $self to the aliased class
                    return sub {  &$coderef($alias_class) };
                }
            }
        }
    }
    return undef;
}


sub _find_template_sub {
    my $self = shift;
    my $subname = shift;
    return $self->can($subname);
}

sub _template_name_to_sub {
    return _subname( "_jifty_template_", shift);

}

sub _template_name_to_private_sub {
    return _subname( "_jifty_private_template_", shift);
}

sub _subname {
    my $prefix = shift;
    my $template = shift ||'';
    $template =~ s{^/+}{};
    $template =~ s{/+}{/}g;
    return join ('', $prefix,$template);
}

=head2 register_template PACKAGE TEMPLATE_NAME CODEREF

This method registers a template called C<TEMPLATE_NAME> in package
C<PACKAGE>. As you might guess, C<CODEREF> defines the template's
implementation.

=cut

sub register_template {
    my $class         = shift;
    my $template_name = shift;
    my $code          = shift;
    push @{ __PACKAGE__->templates()->{$class} }, $template_name;
    _register_template( $class, _template_name_to_sub($template_name), $code )

}

=head2 register_template PACKAGE TEMPLATE_NAME CODEREF

This method registers a private template called C<TEMPLATE_NAME> in package
C<PACKAGE>. As you might guess, C<CODEREF> defines the template's
implementation. 

Private templates can't be called directly from user code but only from other 
templates.

=cut

sub register_private_template {
    my $class         = shift;
    my $template_name = shift;
    my $code          = shift;
    push @{ __PACKAGE__->private_templates()->{$class} }, $template_name;
    _register_template( $class, _template_name_to_private_sub($template_name),
        $code );

}

sub _register_template {
    my $self    = shift;
    my $class   = ref($self) || $self;
    my $subname = shift;
    my $coderef = shift;
    no strict 'refs';
    *{ $class . '::' . $subname } = $coderef;
}




=head1 BUGS

Crawling all over, baby. Be very, very careful. This code is so cutting edge, it can only be fashioned from carbon nanotubes.

Some specific bugs and design flaws that we'd love to see fixed

=over

=item Output isn't streamy.

=back

If you run into bugs or misfeatures, please report them to
C<bug-template-declare@rt.cpan.org>.


=head1 SEE ALSO

L<Jifty>

=head1 AUTHOR

Jesse Vincent <jesse@bestpractical.com>

=head1 COPYRIGHT

Copyright 2006-2007 Best Practical Solutions, LLC

=cut

1;
