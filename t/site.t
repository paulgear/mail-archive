#!/usr/bin/perl -w
#
# site tests for mail archiver
#
# Copyright (c) 2012 Lowenstein & Stumpo <http://www.lowstump.com.au/>
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
use Test::More;
use strict;
use warnings;

use_ok( "MailArchive::Config" );
use_ok( "MailArchive::Log" );

setdebug(0);

require "site.pl";

# check all of the passed strings for a valid project number
#sub check_project_num (@)

# test invalid/missing project numbers
sub check_project_num_invalid
{
	my $short = shift;	# check project numbers which are too short
	my $long = shift;	# check project numbers which are too long
	my $start = shift;	# check project numbers which don't start on a word boundary
	my $end = shift;	# check project numbers which don't end on a word boundary

	# misc checks
	is(check_project_num(undef), undef);		# undef
	is(check_project_num(""), undef);		# empty
	is(check_project_num("     ", "\n"), undef);	# whitespace
	is(check_project_num("Hello world"), undef);	# no number

	if ($short) {
		is(check_project_num("FN 000000", "FN0 00000"), undef);
		is(check_project_num(" FN 00000 "), undef);
		is(check_project_num("FN", "FN000", "FN00000"), undef);
	}

	if ($long) {
		is(check_project_num("FN0000000"), undef);
		is(check_project_num("FN00000000"), undef);
		is(check_project_num("asdf FN00000000"), undef);
		is(check_project_num("asdf FN00000000 qwer"), undef);
	}

	if ($start) {
		is(check_project_num("asdfghjklFN000000"), undef);
		is(check_project_num("asdfghjklFN000000 asdf"), undef);
	}

	if ($end) {
		is(check_project_num("FN000000asdf"), undef);
		is(check_project_num("asdf FN000000asdf"), undef);
	}
}

# test valid project number combinations
sub check_project_num_valid
{
	my $fn = shift;
	my $result = shift;
	$result = $fn unless defined $result;
	is(check_project_num("", $fn), $result);
	is(check_project_num("$fn"), $result);
	is(check_project_num(" $fn "), $result);
	is(check_project_num(" ($fn) "), $result);
	is(check_project_num("      ", "$fn\n", "    ", "$fn\n"), $result);
	is(check_project_num("", "before NF0000", "before $fn", "after"), $result);
	is(check_project_num("$fn after"), $result);
	is(check_project_num("before $fn after"), $result);
	is(check_project_num("Hello world $fn"), $result);
	is(check_project_num("A very long subject containing, but not limited to, $fn is what this string represents."), $result);
}

my $re;
$re = '\b(FN\d{6})\b';
setconfig('projnum-regex', $re);
print "Testing '$re'\n";
check_project_num_invalid(1, 1, 1, 1);
check_project_num_valid("FN123456");
check_project_num_valid("FN000000");

$re = '\b(FN\d{6})';
setconfig('projnum-regex', $re);
print "Testing '$re'\n";
check_project_num_invalid(1, 0, 1, 0);
check_project_num_valid("FN123456");
check_project_num_valid("FN1234567", "FN123456");
check_project_num_valid("FN0000001", "FN000000");

$re = '(FN\d{6})\b';
setconfig('projnum-regex', $re);
print "Testing '$re'\n";
check_project_num_invalid(1, 1, 0, 1);
check_project_num_valid("FN123456");
check_project_num_valid("aFN123456", "FN123456");
check_project_num_valid("asdfFN000000", "FN000000");

$re = '(FN\d{6})';
setconfig('projnum-regex', $re);
print "Testing '$re'\n";
check_project_num_invalid(1);
check_project_num_valid("FN123456");
check_project_num_valid("FN1234567", "FN123456");
check_project_num_valid("FN0000001", "FN000000");
check_project_num_valid("aFN123456", "FN123456");
check_project_num_valid("asdfFN000000", "FN000000");
check_project_num_valid("aFN123456789", "FN123456");
check_project_num_valid("asdfFN0000001234", "FN000000");
check_project_num_valid("asdfFN000000asdf", "FN000000");

$re = '(FN\d+)';
setconfig('projnum-regex', $re);
print "Testing '$re'\n";
check_project_num_invalid();
check_project_num_valid("FN1");
check_project_num_valid("FN123");
check_project_num_valid("FN12345");
check_project_num_valid("FN123456");
check_project_num_valid("FN1234567");
check_project_num_valid("FN0000001");
check_project_num_valid("aFN123456", "FN123456");
check_project_num_valid("asdfFN000000", "FN000000");
check_project_num_valid("aFN123456789", "FN123456789");
check_project_num_valid("asdfFN0000001234", "FN0000001234");
check_project_num_valid("asdfFN000000asdf", "FN000000");

$re = '(FN\d*)';
setconfig('projnum-regex', $re);
print "Testing '$re'\n";
check_project_num_invalid();
check_project_num_valid("FN");
check_project_num_valid("FN1");
check_project_num_valid("FN123");
check_project_num_valid("FN12345");
check_project_num_valid("FN123456");
check_project_num_valid("FN1234567");
check_project_num_valid("FN0000001");
check_project_num_valid("aFN123456", "FN123456");
check_project_num_valid("asdfFN000000", "FN000000");
check_project_num_valid("aFN123456789", "FN123456789");
check_project_num_valid("asdfFN0000001234", "FN0000001234");
check_project_num_valid("asdfFN000000asdf", "FN000000");

setconfig('projnum-regex', 'FN\d{6}');
check_project_num_invalid(1);
#TODO add check for valid numbers returning undef

# TODO get the two-, four-, and six-digit versions of the file number
#sub split_projnum ($)
#$config{'projnum-split-regex'}	= '^FN(\d\d)(\d\d)(\d\d)$';

# TODO get the two-, four-, and six-digit versions of the file number
#sub split_projnum ($)
#$config{'projnum-split-regex'}	= '^FN(\d\d)(\d\d)(\d\d)$';

# TODO find a directory for this project
#sub get_project_dir ($$)

# TODO get the email directory for this project
#sub get_project_email_dir ($$)

done_testing();
