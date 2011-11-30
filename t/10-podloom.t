#! /usr/bin/perl
#---------------------------------------------------------------------
# Copyright 2011 Christopher J. Madsen
#
# Test Dist::Zilla plugin for Pod::Loom
#---------------------------------------------------------------------

use strict;
use warnings;
use 5.008;
use utf8;

use Test::More 0.88;  # want done_testing

use Test::DZil qw(Builder);
use Encode qw(decode);

# Load Test::Differences, if available:
BEGIN {
  if (eval "use Test::Differences; 1") {
    # Not all versions of Test::Differences support changing the style:
    eval { Test::Differences::unified_diff() }
  } else {
    eval '*eq_or_diff = \&is;'; # Just use "is" instead
  }
} # end BEGIN

#=====================================================================
my $generateResults;

if (@ARGV and $ARGV[0] eq 'gen') {
  # Just output the actual results, so they can be diffed against this file
  $generateResults = 1;
  open(OUT, '>:utf8', '/tmp/10-podloom.t') or die $!;
  printf OUT "#%s\nmy \$expected = <<'END EXPECTED';\n", '=' x 69;
} else {
  plan tests => 2;
}

#=====================================================================
my $expected = <<'END EXPECTED';
package DZT::Sample;
# ABSTRACT: Sample DZ Dist

use strict;
use warnings;

our $VERSION = '0.04';

1;

__END__

=encoding utf8

=head1 NAME

DZT::Sample - Sample DZ Dist

=head1 VERSION

This is the version section.

=head1 SYNOPSIS

  use DZT::Sample;

=head1 DEPENDENCIES

DZT::Sample requires ümlauts.

=head1 AUTHOR

E. Xavier Ample  S<C<< <example AT example.org> >>>

=cut
END EXPECTED

#=====================================================================
{
  my $tzil = Builder->from_config(
    { dist_root => 'corpus/DZT' },
  );

  $tzil->build;
  ok(1, 'built ok') unless $generateResults;

  my $got = decode('utf8', $tzil->slurp_file('build/lib/DZT/Sample.pm'));

  $got =~ s/\n(?:[ \t]*\n)+/\n\n/g; # Normalize blank lines

  if ($generateResults) {
    print OUT $got . "END EXPECTED\n";
  } else {
    eq_or_diff($got, $expected, 'expected content');
  }
}

done_testing unless $generateResults;

# Local Variables:
# compile-command: "cd .. && perl t/10-podloom.t gen"
# End:
