#!/usr/bin/perl -w
#
# perl fragment to manage site-specific code for mail-archive
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

use strict;

use File::Path qw/make_path/;

use MailArchive::Config;
use MailArchive::Util;


# check that this is a valid project number
sub check_project_num ($)
{
	my $projnum = shift;
	my $projnum_regex = getconfig('projnum-regex');
	my @match = $projnum =~ /$projnum_regex/;
	my $ret = ($#match == 0 ? $match[0] : undef);
	debug "Project number is " . (defined $ret ? $ret : "UNDEFINED");
	error "Project number $projnum tainted" if tainted($ret);
	return $ret;
}

# get the two-, four-, and six-digit versions of the file number
sub split_projnum ($)
{
	my $projnum_split_regex = getconfig('projnum-split-regex');
	debug "Splitting $_[0] using /$projnum_split_regex/";
	my @list1 = ($_[0] =~ /$projnum_split_regex/);
	my @list = grep { defined $_ } @list1;
	debug "list = @list";
	if ($#list > 0) {
		my @ret = ($list[0], "$list[0]$list[1]", join("", @list));
		debug "returning (@ret)";
		return @ret;
	}
	else {
		return undef;
	}
}

# find a directory for this project
sub get_project_dir ($$)
{
	my ($basedir, $projnum) = @_;
	my ($nn, $nnnn, $nnnnnn) = split_projnum($projnum);

	my @subdirs = (
		"${nn}00-${nn}99",
		"$nn",
		"",
	);

	my @searchpath = @{getconfig('searchpath')};
	# We put the search path and subdirectories inside the number search
	# so that the most exact matches get priority.
	for my $num ($projnum, $nnnnnn, $nnnn) {
		for my $path (@searchpath) {
			$path =~ s/\/*$//;			# remove any trailing /
			for my $subdir (@subdirs) {
				my @dirs = glob "$basedir/$path/$subdir/${num}*";
				if ($#dirs >= 0 && -d $dirs[0]) {
					$dirs[0] =~ /^(.*)$/;
					return $1;		# return untainted value
				}
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

	# check if directory already exists
	if (-d $dir) {
		# if it does, return an error if it's not writable, or the directory if it is
		return -w $dir ? $dir : undef;
	}

	# try to create it if not
	my $err;
	make_path($dir, { error  => $err });
	if (defined $err and @$err) {
		warn "Cannot create directory $dir: $!";
		return undef;
	}
	else {
		return $dir;
	}
}

1;	# file must return true - do not remove this line

