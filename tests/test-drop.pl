#!/usr/bin/perl -w

use lib ".";

require "site.pl";

my $flags = get_drop_flags($ARGV[0], "", "");
if (defined $flags) {
	print "flags = $flags\n";
}
else {
	print "$ARGV[0] NOT matched\n";
}
