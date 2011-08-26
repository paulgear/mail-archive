#!/usr/bin/perl -w

use strict;

#my @a1 = ( 'a', 'b', 'c', undef, 'd' );
#print "a1 = @a1 ($#a1)\n";
#my @a2 = grep { defined $_ } @a1;
#print "a2 = @a2 ($#a2)\n";
#my @a3 = grep { defined $_ } ( 'a', 'b', 'c', undef, 'd' );
#print "a3 = @a3 ($#a3)\n";

my $s1 = "abcdef";
my $s2 = "ghijkl";
my $r = "((ab)(.*)|(gh)(.*))";

my @a1 = ($s1 =~ /$r/);
print "a1 = @a1 ($#a1)\n";
my @a2 = ($s2 =~ /$r/);
print "a2 = @a2 ($#a2)\n";

my @a1 = ($s1 =~ /$r/);
print "a1 = @a1 ($#a1)\n";
my @a2 = ($s2 =~ /$r/);
print "a2 = @a2 ($#a2)\n";
