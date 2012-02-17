use strict;
use warnings;
use Test::More 0.98;
use Test::Fatal;

BEGIN { use_ok 'gather' };

is_deeply
    [gather { take $_ for 1..10; take 99 }],
    [1..10, 99],
    'basic gather works';

is_deeply
    [gather { take 1..10; take 99 }],
    [1..10, 99],
    'taking multiple items works';

is_deeply
    [gather { take $_ for 1..10; take 99 unless gathered }],
    [1..10],
    'gathered works in boolean context (true)';

is_deeply
    [gather { take 99 unless gathered }],
    [99],
    'gathered works in boolean context (false)';

is_deeply
    [gather { take $_ for 1..10; pop gathered }],
    [1..9],
    'gathered allows modification of underlying data';

is_deeply
    [gather {
        for my $x (qw(a b)) {
            sub { take @_ }->($x);
        }
    }],
    [qw(a b)];

is_deeply
    [gather {
        for my $x (qw(a b)) {
            package Moo;
            sub { ::take @_ }->($x);
        }
    }],
    [qw(a b)];

is exception {
    for my $x (qw(a b c)) {
        gather { take $x };
    }
}, undef;

done_testing;
