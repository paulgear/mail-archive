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
use Test::More tests => 170;
use strict;
use warnings;

use_ok( 'MailArchive::Util' );
use_ok( 'MailArchive::Config' );

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

# get_checksum
print "get_checksum\n";
is(get_checksum(undef), undef, "undef");

is(get_checksum(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "empty string");
isnt(get_checksum(""), "01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b", "empty string tested with empty line's checksum");
is(get_checksum("\n"), "01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b", "empty line");
isnt(get_checksum("\n"), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "empty line tested with empty string's checksum");

is(get_checksum("password"), "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8", "'password'");
isnt(get_checksum("password"), "6b3a55e0261b0304143f805a24924d0c1c44524821305f31d9277843b8a10f4e", "'password' but checksum with newline");
is(get_checksum("password\n"), "6b3a55e0261b0304143f805a24924d0c1c44524821305f31d9277843b8a10f4e", "'password' with newline");
isnt(get_checksum("password\n"), "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8", "'password' with newline, but checksum without newline");

is(get_checksum(-1), get_checksum("-1"), "bare number -1");
is(get_checksum(0), get_checksum("0"), "bare number 0");
is(get_checksum(123456), get_checksum("123456"), "bare number 123456");
is(get_checksum(2**32), get_checksum("4294967296"), "32-bit max integer");

is(get_checksum("Hello world\n"), "1894a19c85ba153acbf743ac4e43fc004c891604b26f8c69e1e83ea2afc7c48f", "Hello world with newline");
isnt(get_checksum("Hello world Hello world Hello world"), "1894a19c85ba153acbf743ac4e43fc004c891604b26f8c69e1e83ea2afc7c48f", "Hello world repeated without newline");

my $random = <<EOF;
vL10dxJ9UorARDAgvkhHSeK4CCWdrcrlr5q5vTmsQPmssiwT4l0aND0YMRb+yu/720wjQ8cuSrxN
eIUwuYP44apWy9zkJlbRAfhdbABUCKLZnWsu9Eb/fpVo+cbkuPZtlNpODScj659f6Wh62dXJjyg2
Ds8o/xojCWHJTyeJY2oXrQhwKhCG8kfxwbnY7tgePv5SWCwQ8Hdccqz67MYOgdwbCWz1AjmZwZG+
hO9TIGzx5G6iRsByAZrmh5QI/mLTVRagiUVhv83kh3vPDq9FBC4IBht04XO3/Au32dpXnw0h0hZh
Zg+16vp650X8nmSuIE6LdxFBcGIgG8P/BAzlVKkKL3Tax0ZhL7XGUuR1e5BKh28Q56+ZidAYP8JE
hywErDu47Imj9s2paHvOzMIr5KIQcWsvrSzfU7CrN2EqYbGgbdTB4ync0VfEu50VqKy+0TLQxzMz
Fhh4A/zfoe6IK75T2wYh+mvKWmwfLO1fUaY+R3FCAJU+EAvQ9KEWnU71l6+X4SzhRrYqnVGniHQY
hlZPIa0hGb5oozqLfcgz/VZq5Q9kzQW8ZB4OEB6Tq2YoNUk+R+3c8P3NQx5M3rGYz3es/aiAHrz2
kC5qYQhLMCwU5oLo7ED004ZOUUuRZcvg5R9JXJiQc0aCFc1RoeJjf1RjFNTUCRcbpDEwP/knigcU
ru3FGC+fija6+cLoK/3HhT44yLpCSxB1+68XqCU2gv13n6YzbiiILecVSyKIhdvSMGYeAmTv0pj4
EGRCn7ZPj+Vyw5wL2Hs7hi9Gg0zeLD+Cu76OixV2jcxnsLTY6nd0jntPHrRXZdEpgBUBEXIHAC10
pOyh5CufLnBliHb/0o6lZBcwMLWfcDYOHe52losZ/qwKQv8Uk9uBhh9O9hRl08rPX5PUg4bUkiJh
c4LxBnPNyXJuzfD4dqLqUoQaIzIT4wuQdQqNFoUUDY9Ho97QXnbc6MrwwDSQEKtM7w3QKAY0xUXh
NopYVEyc9wKlR36rQRrVcOy4DFycwqArrviXIA2ZcUcGEbvShq7okVMZz3cl58v9Kbvzt988Kveq
7OXkZL8wuXunIA2aPU/FFvJdslImUHUwyX9kYScBV5OYbY33uEyLmeGWLS/VcV/TqcGSdR1my7Yk
liPtvrXPJrK+Rq4wpGMOYy1jmhGfrWLT73vxxhiakvHm/65QzLCDYHHYUqicozwbvpx1uYmW99wd
TlfyvLbUfQ+7yt5TCOuyw/qwrtCqvtdj9R/E84JPQE+UpkyPhXMh6MbKkxAnmvPIbDyUIuBkhyvv
MVsym16PWn0u6p8x4bXnCyvO2OJFpv1XDKqQutbd74ohOriErjTOf1izvN5Hm/l88nTtGPkuHQ==
EOF
is(get_checksum($random), "43e2d8f9e1f20a1cab1b309c877635bac62fbe31ae0bb56fca07a5393595210a", "1K of random data, base64 encoded");

# check whether the given string consists entirely of vertical or horizontal whitespace
print "is_whitespace\n";
ok( is_whitespace( "    " ), "four spaces" );
ok( is_whitespace( "\t\t" ), "two tabs" );
ok( is_whitespace( "\t    \t\n\t    \t\n" ), "multi-line whitespace" );
ok( ! is_whitespace( "Hello world\n" ), "hello world" );
ok( ! is_whitespace( "helpme" ), "helpme" );
ok( ! is_whitespace( "      \nHelp me!\n     \n" ), "multi-line including whitespace" );

# return an error if we've passed the maximum recursion limit
#sub limit_recursion ($)
print "limit_recursion\n";

# limit_recursion insists on a minimum value of 1 for both its limit and the tested value,
# so if the passed value is < 1, we always expect limit recursion to succeed.
sub adjust_limit_recursion ($)
{
	my $val = shift;
	return $val <= 1 ? limit_recursion($val) : ! limit_recursion($val);
}

sub test_limit_recursion ($)
{
	my $limit = shift;
	setconfig('recursion-level', $limit);
	ok(limit_recursion(-1), "limit_recursion -1");
	ok(limit_recursion(0), "limit_recursion 0");
	ok(limit_recursion($limit / 2), "limit_recursion $limit / 2");
	ok(limit_recursion($limit - 2), "limit_recursion $limit - 2");
	ok(limit_recursion($limit - 1), "limit_recursion $limit - 1");
	ok(limit_recursion($limit - 0), "limit_recursion $limit - 0");
	ok(adjust_limit_recursion($limit + 1), "limit_recursion $limit + 1");
	ok(adjust_limit_recursion($limit + 2), "limit_recursion $limit + 2");
	ok(adjust_limit_recursion($limit + 10), "limit_recursion $limit + 10");
	ok(adjust_limit_recursion($limit * 2), "limit_recursion $limit * 2");
	ok(adjust_limit_recursion($limit * 10), "limit_recursion $limit * 10");
}

test_limit_recursion(-99);
test_limit_recursion(-1);
test_limit_recursion(0);
test_limit_recursion(1);
test_limit_recursion(2);
test_limit_recursion(5);
test_limit_recursion(99);
test_limit_recursion(9999);
test_limit_recursion(999999);

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

# ensure directory is a canonical path and it exists, returning the untainted name
print "validate_directory\n";

my $dir;
$dir = "/";				is( validate_directory($dir), $dir, "Root directory: $dir");
$dir = "/dev";				is( validate_directory($dir), $dir, "System directory: $dir");
$dir = "/var/../tmp";			is( validate_directory($dir), $dir, "Complex: $dir");
$dir = "/var/tmp/../";			is( validate_directory($dir), "/var/tmp/..", "Complex with trailing slash: $dir");
$dir = "/./.././.././//././dev";	is( validate_directory($dir), "/dev", "Leading complex mess: $dir");
$dir = $ENV{'HOME'};			is( validate_directory($dir), $ENV{'HOME'}, "Home directory: $dir");

