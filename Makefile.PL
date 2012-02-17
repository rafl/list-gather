use strict;
use warnings;
use ExtUtils::MakeMaker;

use Devel::CallChecker;
use Devel::CallParser;
use IO::File;

IO::File->new('callchecker0.h', 'w')->print(
    Devel::CallChecker::callchecker0_h,
);

IO::File->new('callparser.h', 'w')->print(
    Devel::CallParser::callparser1_h,
);

WriteMakefile(
    NAME => 'gather',
);
