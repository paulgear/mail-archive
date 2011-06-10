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
	debug
	dump_email_address
	dump_email_addresses
	error
	getdebug
	save_file
	setdebug
	yyyymmdd

);
@EXPORT_OK   = qw(init);
#%EXPORT_TAGS = ( DEFAULT => [qw(&dump_email_address)] );

# code dependencies
use File::Path;
use File::Basename;

my $PROG = "";
my $DEBUG;

sub init ($)
{
	my $prog = shift;	# get rid of module name argument - why is this needed?
	$prog = basename shift;	# get argument
	$prog =~ m/^(.*)$/;	# untaint
	$PROG = $1;
	setdebug(-t 1);
}

sub getdebug ()
{
	return $DEBUG;
}

sub setdebug ($)
{
	$DEBUG = $_[0] ? 1 : 0;
	print STDERR "$PROG: debug is " . ($DEBUG ? "on" : "off") . "\n";
}

sub debug ($)
{
	print "$PROG: $_[0]\n" if $DEBUG;
}

sub error ($)
{
	print STDERR "$PROG: $_[0]\n";
	exit 1;
}

sub dump_email_address ($$)
{
	my ($label, $address) = @_;
	my @attrs = map { $address->$_ } qw(name user host);
	printf STDERR "%s: %s <%s@%s>\n", $label, @attrs;
	#my @attrs = qw(phrase address comment original host user format name);
	#for my $attr (@attrs) {
	#	printf STDERR "\t%-20s  %s\n", $attr, $address->$attr;
	#}
}

sub dump_email_addresses ($@)
{
	my $label = shift;
	for my $email (@_) {
		dump_email_address $label, $email;
	}
}

# get current date in yyyymmdd format
sub yyyymmdd
{
	my $time = shift;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(defined $time ? $time : time());
	$year += 1900;
	my $yyyymmdd = sprintf("%04d%02d%02d", $year, $mon, $mday);
	return $yyyymmdd;
}

# create a directory given a base name and working out a valid sequence number
sub create_seq_directory
{
	my $base = shift;
	my $seq = shift;
	$seq = 999 unless defined $seq;
	for (my $i = 1; $i <= $seq; ++$i) {
		my $dir = "$base $i";
		debug "Trying $dir";
		next if -d $dir;
		next if -e "$dir.eml";
		debug "$dir does not exist yet, creating";
		mkpath $dir;
		debug "made $dir";
		return $dir;
	}
	return undef;
}

sub save_file ($$$)
{
	my ($fname, $msg, $content) = @_;
	open(my $fh, ">$fname")
		or error "Cannot open $msg: $!";
	print $fh $content;
	close $fh
		or error "Cannot close $msg: $!";
	#debug "Saved $fname";
}

1;	# file must return true - do not remove this line

