#!/usr/bin/perl -w
#
# perl fragment to keep configuration for mail-archive
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

use File::Path qw/make_path/;

# mail from one of these domains is considered outgoing
@localdomains = (
	'localhost',
);

# check that this is a valid project number
sub check_project_num ($)
{
	my $projnum = shift;
	my @match = $projnum =~ /\b(FN\d{6})\b/;
	return ($#match == 0 ? $match[0] : undef);
}

# get the two-, four-, and six-digit versions of the file number
sub split_projnum ($)
{
	my @list = ($_[0] =~ /^FN(\d\d)(\d\d)(\d\d)$/);
	if ($#list == 2) {
		return ($list[0], "$list[0]$list[1]", join("", @list));
	}
	else {
		return undef;
	}
}

# find a directory for this project in the common places
sub get_project_dir ($$)
{
	my ($basedir, $projnum) = @_;
	my ($nn, $nnnn, $nnnnnn) = split_projnum($projnum);

	my @searchpath = (
		"$basedir/${nn}00-${nn}99",
		"$basedir/$nn",
		"$basedir",
	);

	for my $path (@searchpath) {
		#print "checking $path\n";
		for my $fnum ($projnum, $nnnnnn, $nnnn) {
			my @dirs = glob "$path/${fnum}*";
			if ($#dirs >= 0 && -d $dirs[0]) {
				$dirs[0] =~ /^(.*)$/;
				return $1;			# return untainted value
			}
		}
	}
	return undef;
}

# get the email directory for this project
sub get_project_email_dir ($$)
{
	my ($projdir, $outgoing) = @_;
	my $dir = "$projdir/correspondence/email " . ($outgoing ? "out" : "in");
	my $ret = make_path($dir);
	return $dir if $ret == 1 or -d $dir;
	warn "Cannot create directory $dir: $!";
	return undef;
}

1; # don't delete this

