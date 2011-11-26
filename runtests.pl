#!/usr/bin/perl -w

use strict;
use warnings;
use Test::Harness qw(&runtests);
my @tests = @ARGV ? @ARGV : <t/*.t>;
runtests @tests;
