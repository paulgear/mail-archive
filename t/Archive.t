#!/usr/bin/perl -w
#
# Message archiving tests for mail archiver
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
use Test::More tests => 1;
use strict;
use warnings;

use_ok( 'MailArchive::Archive' );

# checksum file, find out whether it matches another file in the database
#sub dedup_file ($$)
#	my ($fullpath, $data) = @_;

# save the file and dedup
#sub save_dedup_file ($$$)
#	my ($dir, $file, $content) = @_;

# save the body of the given file part to disk
#sub save_part ($$$)
#	my ($dir, $file, $body) = @_;

# exit with error if we've passed the maximum recursion limit
#sub limit_recursion ($)

#sub process_part ($$$$$$$$$)
#	my ($basedir, $projnum, $dir, $part, $level, $prefix, $partnum, $subject, $smart_drop) = @_;

# save every part of the given message
#sub save_message ($$$$$$$)
#	my ($basedir, $projnum, $dir, $msg, $level, $subject, $smart_drop) = @_;

# main email processor
#sub process_email ($$$$$)
#	my ($basedir, $projnum, $email, $level, $subject_override) = @_;

