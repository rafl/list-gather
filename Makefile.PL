use strict;
use warnings;
use ExtUtils::MakeMaker;

use lib 'inc';
use MMHelper;

eval MMHelper::header_generator();

WriteMakefile(
    NAME    => 'gather',
    CCFLAGS => MMHelper::ccflags_static('dev'),
    MMHelper::mm_args(),
);
