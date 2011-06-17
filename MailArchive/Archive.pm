#!/usr/bin/perl -w
#
# Message handling routines for mail archiver
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

package MailArchive::Archive;

# module setup
use strict;
use warnings;
use Exporter;
use vars qw($VERSION @ISA @EXPORT); # @EXPORT_OK); %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(

	process_message

);
#@EXPORT_OK   = qw( init );

# code dependencies
use Digest;
use File::Compare;
use File::Spec;
use MailArchive::Db;
use MailArchive::Email;
use MailArchive::Util;

my $digest;

sub init ()
{
	$digest = Digest->new("SHA-256");
}

sub compare_file ($$)
{
	debug "This is where we would compare $_[0] and $_[1]";
	return 1;
}

sub link_file ($$)
{
	debug "This is where we would link $_[1] to $_[0]";
	return 1;
}

# checksum file, find out whether it matches another file in the database
sub dedup_file ($$)
{
	init() unless $digest;

	my ($fullpath, $data) = @_;
	$digest->add($data);
	my $cksum = $digest->hexdigest;
	debug "checksum $cksum";

	for my $check_file (check_file($fullpath, $cksum)) {
		# If we have this exact file & checksum already in the db, do nothing.
		# This really shouldn't happen unless we've been deleting files without
		# cleaning up the database.
		return if $check_file eq $fullpath;

		# we didn't find a matching file
		next unless defined $check_file;

		# the file in the database doesn't exist
		next unless -e $check_file;

		# the files are not identical
		next unless compare($check_file, $fullpath) == 0;

		# move the file aside
		#debug "rename $fullpath -> $fullpath.tmp";
		rename($fullpath, "$fullpath.tmp")
			or error "Cannot move aside $fullpath";

		# hard link it to the matching file
		#debug "link $fullpath -> $check_file";
		if (link($check_file, $fullpath)) {
			#debug "unlink $fullpath.tmp";
			unlink("$fullpath.tmp")
				or warn "Cannot delete $fullpath.tmp - please delete manually";
			# we're done - don't check against any more files
			last;
		}
		else {
			warn "Cannot link $fullpath to $check_file";
			#debug "rename $fullpath.tmp -> $fullpath";
			rename("$fullpath.tmp", $fullpath)
				or warn "Cannot move back $fullpath - please rename manually";
		}
	}
	add_file($fullpath, $cksum);
}

# save the body of the given file part to disk
sub save_part ($$$)
{
	my ($dir, $filename, $body) = @_;
	if (is_whitespace($body)) {
		# don't save empty parts
		debug "Message part $filename empty - dropping";
		return;
	}
	my $fullpath = File::Spec->catfile($dir, $filename);
	error "File $fullpath already exists" if -e $fullpath;
	save_file($fullpath, "message part file", $body);
	dedup_file($fullpath, $body);
}

sub save_message ($$$)
{
	my ($dir, $msg, $level) = @_;

	# FIXME: configurable limit
	if ($level > 99) {
		error "Reached maximum recursion level in message";
	}

	# TODO: Add processing of stats here

	# save the message headers to disk
	save_part($dir, "headers$level.txt", concatenate_headers($msg->header_pairs()));

	my $numparts = $msg->parts;
	debug $msg->debug_structure;

	my $partnum = 1;
	for my $part ($msg->parts) {
		my $type = $part->content_type;
		debug "part $partnum: $type";
		my $filename = (defined $part->filename) ? $part->filename : $part->invent_filename($type);
		debug "part $partnum name: $filename";
		if (scalar $part->subparts > 0) {
			my $subpartnum = 1;
			for my $subpart ($part->subparts) {
				my $subtype = $subpart->content_type;
				debug "part $partnum subpart $subpartnum: $subtype";
				my $subfilename = (defined $subpart->filename) ? $subpart->filename : $subpart->invent_filename($subtype);
				debug "part $partnum subpart $subpartnum name: $subfilename";
				save_part($dir, $subfilename, $subpart->body);
			}
		}
		elsif ($type =~ /^message\//) {
			debug "recursing, message type = $type";
			save_message($dir, $part, $level + 1);
		}
		else {
			save_part($dir, $filename, $part->body);
		}
		++$partnum;
	}
}

sub process_message ($$)
{
	my $uniquebase = shift;
	my $msg = shift;

	my $dir = create_seq_directory($uniquebase);
	save_message($dir, $msg, 1);
}

1;	# file must return true - do not remove this line

