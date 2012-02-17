use strict;
use warnings;
use Test::More 0.98;

BEGIN { use_ok 'gather' };

my @x = gather sub {
    take 42;
    take 23;
    take $_ for qw( a b c );
    take qw(foo bar baz);
};

diag explain \@x;

done_testing;
