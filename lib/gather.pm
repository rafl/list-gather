package gather;

use strict;
use warnings;
use Devel::CallChecker;

use XSLoader;

XSLoader::load(__PACKAGE__);

use Sub::Exporter -setup => {
    exports => ['gather', 'take'],
    groups  => { default => ['gather', 'take'] },
};

1;
