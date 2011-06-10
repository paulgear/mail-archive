#!/usr/bin/perl -w
#
# perl fragment to manage configuration for mail-archive
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

use lib ".";

use MailArchive::Util;

# defaults for configurable variables - see config.pl for description
my $projnum_regex = '\b(FN\d{6})\b';
my $projnum_split_regex = '^FN(\d\d)(\d\d)(\d\d)$';
my @searchpath = ( '/', '/files' );
my @localdomains = ( 'localhost' );
my $drop_subject_regex = '\b[(\[]PERSONAL[)\]]\b';

# defaults for variables which should not need changing
$magic_header = "X-MailArchive-Status";

# pull in the site settings
require "config.pl";


# check that this is a valid project number
sub check_project_num ($)
{
	my $projnum = shift;
	my @match = $projnum =~ /$projnum_regex/;
	return ($#match == 0 ? $match[0] : undef);
}

# get the two-, four-, and six-digit versions of the file number
sub split_projnum ($)
{
	my @list = ($_[0] =~ /$projnum_split_regex/);
	if ($#list == 2) {
		return ($list[0], "$list[0]$list[1]", join("", @list));
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

	# We put the search path and subdirectories inside the number search
	# so that the most exact matches get priority.
	for my $num ($projnum, $nnnnnn, $nnnn) {
		for my $path (@searchpath) {
			$path =~ s/\/*$//;			# remove any trailing /
			for my $subdir (@subdirs) {
				#debug "num = $num, path = $path, subdir = $subdir";
				my @dirs = glob "$basedir/$path/$subdir/${num}*";
				#debug "dirs = @dirs";
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
	my $ret = make_path($dir);
	return $dir if $ret == 1 or -d $dir;
	warn "Cannot create directory $dir: $!";
	return undef;
}

# determine whether the email is outgoing by checking whether the domain of
# the sender occurs in @localdomains
sub is_outgoing ($)
{
	my @fromaddr = @_;
	my $fromdom = $fromaddr[0]->host;
	debug "fromdom = $fromdom";
	my $outgoing = grep {$_ eq $fromdom} @localdomains;
	debug "outgoing = $outgoing";
	debug "Email is " . ($outgoing ? "outgoing" : "incoming");
	return $outgoing;
}

# return non-null textual description if the email should be dropped without archiving
sub get_drop_flags ($$$)
{
	my ($subject, $from, $to) = @_;
	if ($subject =~ /$drop_subject_regex/i) {
		return "Personal email";
	}
	return undef;
}

1;	# file must return true - do not remove this line

