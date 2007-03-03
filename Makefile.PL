use inc::Module::Install;

name            'Template-Declare';
license         'perl';
author          'Jesse Vincent <jesse@bestpractical.com>';
all_from        'lib/Template/Declare.pm';
build_requires  'HTML::Lint';
build_requires  'Test::More';
requires 'Class::Accessor';
requires 'Class::Data::Inheritable';
WriteAll;
