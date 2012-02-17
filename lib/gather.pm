package gather;
# ABSTRACT: Construct lists procedurally without temporary variables

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

=head1 SYNOPSIS

  my @list = gather {
      # Try to extract odd numbers and odd number names...
      for (@data) {
          if (/(one|three|five|seven|nine)$/) {
              take qq{'$_'};
          }
          elsif (/^\d+$/ && $_ %2) {
              take $_;
          }
      }

      # But use the default set if there aren't any of either...
      take @defaults unless gathered;
  }

=head1 DESCRIPTION

This module provides a C<gather> keyword that allows lists to be constructed
procedurally, without the need for a temporary variable.

Within the block controlled by a C<gather> any call to C<take> pushes that
call's argument list to an implicitly created array.

C<gather> returns the list of values taken during its block's execution.

=func gather

  gather { ... };
  gather({ ... });

Executes the block it has been provided with, collecting all arguments passed to
C<take> calls within it. After execution, the list of values collected is
returned.

Parens around the C<gather> block are optional.

=func take

  take LIST;

Collects a C<LIST> of values within the currently executing C<gather> block.

C<take> returns no meaningful value.

C<take> calls outside of the lexical scope of a C<gather> block are compile time
errors. Calling C<take> is only legal within the dynamic scope its associated
C<gather> block.

=func gathered

  gathered;

Returns the list of items collected so far during the execution of a C<gather>
block.

C<gathered> calls outside of the lexical scope of a C<gather> block are compile
time errors. Calling C<gathered> outside of the dynamic scope of its associated
C<gather> block is legal.

=cut

1;
