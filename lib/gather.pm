package gather;

use strict;
use warnings;
use Devel::CallParser;
use Devel::CallChecker;

use XSLoader;

XSLoader::load(__PACKAGE__);

my @keywords;
BEGIN { @keywords = qw(gather take gathered) }

use Sub::Exporter -setup => {
    exports => [@keywords],
    groups  => { default => [@keywords] },
};

1;
