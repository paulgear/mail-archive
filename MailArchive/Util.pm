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
	is_whitespace
	read_stdin
	save_file
	validate_directory
	yyyymmdd

);
#@EXPORT_OK   = qw(mysub1);
#%EXPORT_TAGS = ( DEFAULT => [qw(&mysub2)] );

# code dependencies
use Date::Parse;
use File::Path;
use File::Spec;
use Scalar::Util qw/tainted/;

use MailArchive::Config;
use MailArchive::Log;

# Given a base and a maximum sequence number (default 999),
# find the first unused name in the sequence.
sub check_seq_file_or_dir
{
	my $base = shift;
	my $seq = shift;
	$seq = 999 unless defined $seq;
	for (my $i = 1; $i <= $seq; ++$i) {
		my $num = sprintf "%04d", $i;
		my $f = "$base $num";
		next if -d $f;
		#next if -e "$f.eml";
		return $f;
	}
	return undef;
}

# create a directory given a base name and working out a valid sequence number
sub create_seq_directory
{
	my $dir = check_seq_file_or_dir(@_);
	if (defined $dir) {
		mkpath $dir
			or error "Cannot create directory $dir: $!";
		debug "made $dir";
	}
	return $dir;
}

# check whether the given string consists entirely of vertical or horizontal whitespace
sub is_whitespace ($)
{
	return 1 unless defined $_[0];
	return $_[0] =~ /^([[:space:]]|\R)*$/s;
}

# read all of standard input into a single scalar and return it
sub read_stdin ()
{
	local $/ = undef;
	my $stdin = <>;
	return $stdin;
}

# save the given content to the file
sub save_file ($$$)
{
	my ($fname, $msg, $content) = @_;
	open(my $fh, ">$fname")
		or error "Cannot create file $fname: $!";
	print $fh $content;
	close $fh
		or error "Cannot close $fname: $!";
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

# get current (or supplied) date in yyyymmdd format
sub yyyymmdd
{
	my $time = shift;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
		localtime(defined $time ? $time : time());
	$year += 1900;		# year is 1900-based
	$mon  += 1;		# month is 0-based
	my $yyyymmdd = sprintf("%04d%02d%02d", $year, $mon, $mday);
	return $yyyymmdd;
}

1;	# file must return true - do not remove this line

