#!/usr/bin/perl -w
#
# Utility tests for mail archiver
#
# Copyright (c) 2011 Lowenstein & Stumpo <http://www.lowstump.com.au/>
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Author:	Paul Gear <github@libertysys.com.au>
#

# module setup
use Test::More tests => 65;
use strict;
use warnings;

use_ok( 'MailArchive::Util' );

use File::Path;

# Given a base and a maximum sequence number (default 99),
# find the first unused directory name in the sequence.
# Ensure the directory name used is sufficiently less than the overall
# path length limit to enable files to be created within it.
# Maximum path length is maxpath minus room for:
#	1 space
#	2 digit sequence number
#	1 path separator
#	14 character filename following
#sub check_seq_directory
#	my $base = shift;
#	my $seq = shift;

# create a directory given a base name and working out a valid sequence number
#sub create_seq_directory
#	my $dir = check_seq_directory(@_);

# get current (or supplied) date in yymmdd format
print "datestring\n";
my $result = `date +%y%m%d`;
chomp($result);
is( datestring(), $result, "Current time" );
is( datestring( 0 ), "700101", "01 Jan 1970 (epoch)" );
is( datestring( 660956564 ), "901212", "12 Dec 1990" );
is( datestring( 1321912328 ), "111122", "22 Nov 2011" );
is( datestring( 2643824656 ), "531012", "12 October 2053" );

# remove surrounding single or double quotes from the passed string
print "dequote\n";
is(dequote("Hello World"), "Hello World", "no quotes");
is(dequote("Hello 'help me' World"), "Hello 'help me' World", "quotes in the middle");
is(dequote("'Hello 'help me' World'"), "Hello 'help me' World", "nested quotes in the middle");
is(dequote("'Hello World'"), "Hello World", "single quotes");
is(dequote('"Hello World"'), "Hello World", "double quotes");
is(dequote("'Hello World\""), "'Hello World\"", "mismatched quotes");
is(dequote("'Hello World"), "'Hello World", "opening quote");
is(dequote("Hello World'"), "Hello World'", "closing quote");
is(dequote("''Hello World''"), "Hello World", "nested single quotes");
is(dequote("'\"Hello World\"'"), "Hello World", "nested double quotes");
is(dequote('"""Hello World"""'), "Hello World", "triple nested double quotes");
is(dequote("'''Hello World'''"), "Hello World", "triple nested single quotes");
is(dequote("''Hello World'"), "'Hello World", "nested opening quote");
is(dequote("'Hello World''"), "Hello World'", "nested closing quote");
is(dequote("Seamus O'Malley"), "Seamus O'Malley", "stereotypical Irish name");
is(dequote("'Seamus O'Malley'"), "Seamus O'Malley", "stereotypical Irish name - single quotes");
is(dequote('"Seamus O\'Malley"'), "Seamus O'Malley", "stereotypical Irish name - double quotes");
is(dequote("John 'Truck' Smith"), "John 'Truck' Smith", "stereotypical footballer name");
is(dequote("'John 'Truck' Smith'"), "John 'Truck' Smith", "stereotypical footballer name - single quotes");
is(dequote('"John \'Truck\' Smith"'), "John 'Truck' Smith", "stereotypical footballer name - double quotes");

# check whether the given string consists entirely of vertical or horizontal whitespace
print "is_whitespace\n";
ok( is_whitespace( "    " ), "four spaces" );
ok( is_whitespace( "\t\t" ), "two tabs" );
ok( is_whitespace( "\t    \t\n\t    \t\n" ), "multi-line whitespace" );
ok( ! is_whitespace( "Hello world\n" ), "hello world" );
ok( ! is_whitespace( "helpme" ), "helpme" );
ok( ! is_whitespace( "      \nHelp me!\n     \n" ), "multi-line including whitespace" );

# if the path is too long to be a valid Windows path, return the length, otherwise return 0
print "path_too_long\n";

my $str;
$str = "/abcd" x 51;
ok( ! path_too_long($str), length($str) . " char string" );
ok( path_too_long($str, 1), length($str) . " char string with 1 char margin" );

$str = "/asd" x 4 x 16;
ok( path_too_long($str), length($str) . " char string" );
ok( path_too_long($str, 1), length($str) . " char string with 1 char margin" );

$str = "/asd" x 4 x 15;
ok( ! path_too_long($str), length($str) . " char string" );
ok( ! path_too_long($str, -100), length($str) . " char string with -100 char margin" );
ok( ! path_too_long($str, -1), length($str) . " char string with -1 char margin" );
ok( ! path_too_long($str, 0), length($str) . " char string with 1 char margin" );
ok( ! path_too_long($str, 1), length($str) . " char string with 1 char margin" );
ok( ! path_too_long($str, 15), length($str) . " char string with 15 char margin" );
ok( path_too_long($str, 16), length($str) . " char string with 16 char margin" );
ok( path_too_long($str, 17), length($str) . " char string with 17 char margin" );
ok( path_too_long($str, 254), length($str) . " char string with 254 char margin" );
ok( path_too_long($str, 255), length($str) . " char string with 255 char margin" );
ok( ! path_too_long($str, 256), length($str) . " char string with 256 char margin" );
ok( path_too_long($str, length($str)), length($str) . " char string with " . length($str)
	. " char margin" );

# read all of standard input into a single scalar and return it
#sub read_stdin ()

print "setup for save_file and shorten_path\n";

my $dir;
my $base = "/tmp/abcdefghi";
$dir = $base . ("/abcdefghi" x 22);
mkpath $dir;

# save the given content to the file
#sub save_file ($$)
#	my ($fname, $content) = @_;
print "save_file\n";

save_file( "$dir/shorten-me-2.csv", "Hello world\n" );

# Cut off words in the file name until the total path length is short enough,
# keeping the original extension.  Use simple truncation if other shortening
# techniques fail.  Ensure the file name is unique.
#sub shorten_path ($)
#	my $path = shift;
print "shorten_path\n";

is( shorten_path("$dir/"), "$dir/0001", "just the dirname" );
is( shorten_path("$dir/noextension"), "$dir/noextension", "no extension" );
is( shorten_path("$dir/dotextension."), "$dir/dotextension.", "single dot extension" );
is( shorten_path("$dir/a.longextension"), "$dir/a.longextension", "long extension" );
ok( ! defined shorten_path("$dir/a.reallyverybiglongextension"), "very long extension" );
is( shorten_path("$dir/shortenough.csv"), "$dir/shortenough.csv", "single-word basename - short enough already" );
is( shorten_path("$dir/notquiteshortenough.csv"), "$dir/notquitesho.csv", "single-word basename - not short enough" );
is( shorten_path("$dir/shorten-me-please.csv"), "$dir/shorten-me.csv", "multi-word basename" );
is( shorten_path("$dir/shorten me please.csv"), "$dir/shorten me.csv", "multi-word basename" );
is( shorten_path("$dir/shorten-me-1-more-time.csv"), "$dir/shorten-me-1.csv", "multi-word basename, file doesn't exist" );
is( shorten_path("$dir/shorten-me-2-more-times.csv"), "$dir/shorten-me-2 0001.csv", "multi-word basename, file exists" );

print "cleanup from save_file and shorten_path\n";
rmtree $base;

# ensure directory is a canonical path and it exists, returning the untainted name
print "validate_directory\n";

$dir = "/";				is( validate_directory($dir), $dir, "Root directory: $dir");
$dir = "/dev";				is( validate_directory($dir), $dir, "System directory: $dir");
$dir = "/var/../tmp";			is( validate_directory($dir), $dir, "Complex: $dir");
$dir = "/var/tmp/../";			is( validate_directory($dir), "/var/tmp/..", "Complex with trailing slash: $dir");
$dir = "/./.././.././//././dev";	is( validate_directory($dir), "/dev", "Leading complex mess: $dir");
$dir = $ENV{'HOME'};			is( validate_directory($dir), $ENV{'HOME'}, "Home directory: $dir");

