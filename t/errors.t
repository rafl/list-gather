use strict;
use warnings;
use Test::More 0.89;
use Test::Fatal;

use gather;

my $taker = gather {
    take sub { take 42 };
};

like exception { $taker->() },
    qr/^attempting to take after gathering already completed/;

eval 'sub { take 42 }';
like $@, qr/^illegal use of take outside of gather/;

my $gathered = gather {
    take sub { gathered }
};

like exception { $gathered->() },
    qr/^attempting to call gathered after gathering already completed/;

eval 'sub { gathered }';
like $@, qr/^illegal use of gathered outside of gather/;

eval { &gather(sub{}) };
like $@, qr/^gather called as a function/;
eval { &take(24) };
like $@, qr/^take called as a function/;
eval { &gathered(24) };
like $@, qr/^gathered called as a function/;

done_testing;
