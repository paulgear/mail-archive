#!/usr/bin/perl -w
#
# Utility functions for mail archiver
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

package MailArchive::Util;

# module setup
use strict;
use warnings;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK); # %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(

	create_seq_directory
	datestring
	dequote
	is_whitespace
	path_too_long
	read_stdin
	save_file
	shorten_path
	validate_directory

);
#@EXPORT_OK   = qw(mysub1);
#%EXPORT_TAGS = ( DEFAULT => [qw(&mysub2)] );

# code dependencies
use File::Basename;
use File::Path;
use File::Spec;
use Scalar::Util qw/tainted/;

use MailArchive::Config;
use MailArchive::Log;

# Given a base and a maximum sequence number (default 99),
# find the first unused directory name in the sequence.
# Ensure the directory name used is sufficiently less than the overall
# path length limit to enable files to be created within it.
# Maximum path length is maxpath minus room for:
#	1 space
#	2 digit sequence number
#	1 path separator
#	14 character filename following
sub check_seq_directory
{
	my $base = shift;
	my $seq = shift;
	$seq = 99 unless defined $seq;
	my $maxlen = getconfig('maxpath') - 18;
	for (my $i = 1; $i <= $seq; ++$i) {
		my $f = sprintf "%.*s %02d", $maxlen, $base, $i;
		next if -d $f;
		return $f;
	}
	return undef;
}

# create a directory given a base name and working out a valid sequence number
sub create_seq_directory
{
	my $dir = check_seq_directory(@_);
	if (defined $dir) {
		mkpath $dir
			or error "Cannot create directory $dir: $!";
		debug "made $dir";
	}
	return $dir;
}

# remove surrounding single or double quotes from the passed string
sub dequote ($)
{
	my $ret = $_[0];
	while ($ret =~ /^('.*'|".*")$/) {
		$ret =~ s/^'(.*)'$/$1/g;
		$ret =~ s/^"(.*)"$/$1/g;
	}
	return $ret;
}

# check whether the given string consists entirely of vertical or horizontal whitespace
sub is_whitespace ($)
{
	return 1 unless defined $_[0];
	return $_[0] =~ /^([[:space:]]|\R)*$/s;
}

# if the path is too long to be a valid Windows path, return the length, otherwise return 0
sub path_too_long
{
	my $path = shift;
	my $margin = shift;
	my $max = getconfig('maxpath');
	$margin = 0 unless defined $margin;
	$margin = 0 if $margin < 0 or $margin > $max;
	my $len = length($path);
	if ($len + $margin > $max) {
		#warning "Path too long ($len characters): $_[0]";
		return $len;
	}
	else {
		return 0;
	}
}

# read all of standard input into a single scalar and return it
sub read_stdin ()
{
	local $/ = undef;
	my $stdin = <>;
	return $stdin;
}

# save the given content to the file
sub save_file ($$)
{
	my ($fname, $content) = @_;
	open(my $fh, ">$fname")
		or error "Cannot create file $fname: $!";
	print $fh $content;
	close $fh
		or error "Cannot close $fname: $!";
}

# Cut off words in the file name until the total path length is short enough,
# keeping the original extension.  Use simple truncation if other shortening
# techniques fail.  Ensure the file name is unique.
sub shorten_path ($)
{
	my $path = shift;
	my $max = getconfig('maxpath');

	# enforce length limit
	for (my $len = length($path); $len > $max; $len = length($path)) {
		# split path into dirname, basename, and extension
		my ($base, $dir, $ext) = fileparse($path, qr/\.[^.]*/);
		if ($base =~ /[[:punct:]\s]+/) {
			# if there are still punctuation or space chars, eliminate the last word
			$base =~ s/[[:punct:]\s]+[[:alpha:][:digit:]]+\s*$//;
			$path = "$dir$base$ext";
		}
		else {
			# otherwise, just truncate it
			$base = substr($base, 0, $max - length($dir) - length($ext) - 3);
			$path = "$dir$base$ext";
			$len = length($path);
			if ($len > $max) {
				# we failed (because $dir or $ext was too long)
				return undef;
			}
		}
	}

	# ensure file is unique
	my $i = 1;
	my ($base, $dir, $ext) = fileparse($path, qr/\.[^.]*/);
	while (-e $path) {
		# sleep a random amount in case we have multiple instances competing
		sleep(rand($i % 5));

		# construct a new path using the sequence number
		$path = sprintf "%s%s%s%02d%s", $dir, $base, $base eq "" ? "" : " ", $i, $ext;

		++$i;
		if ($i > 99) {
			# we failed to find a unique file
			return undef;
		}
	}
	return $path;
}

# ensure directory is a canonical path and it exists, returning the untainted name
sub validate_directory ($)
{
	my $dir = shift;
	$dir = File::Spec->canonpath($dir);
	error "Base directory $dir not found" unless -d $dir;
	$dir =~ /^(.*)$/;
	$dir = $1;
	error "Base directory $dir tainted" if tainted($dir);
	return $dir;
}

# get current (or supplied) date in yymmdd format
sub datestring
{
	my $time = shift;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
		localtime(defined $time ? $time : time());
	$year += 1900;		# year is 1900-based - convert to real year
	$year %= 100;		# truncate year to 2 digits
	$mon  += 1;		# month is 0-based
	my $result = sprintf("%02d%02d%02d", $year, $mon, $mday);
	return $result;
}

1;	# file must return true - do not remove this line

