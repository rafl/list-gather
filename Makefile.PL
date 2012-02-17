use strict;
use warnings;
use ExtUtils::MakeMaker;

use Devel::CallChecker;
use IO::File;

IO::File->new('callchecker0.h', 'w')->print(
    Devel::CallChecker::callchecker0_h,
);

WriteMakefile(
    NAME => 'gather',
);
