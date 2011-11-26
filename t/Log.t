#!/usr/bin/perl -w
#
# Logging tests for mail archiver
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

use_ok( 'MailArchive::Log' );

#sub init ($)
#	my $prog = shift;	# get rid of module name argument - why is this needed?
#	$prog = basename shift;	# get argument

#sub getdebug ()
#sub setdebug ($)
#sub debug ($)
#sub warning ($)
#sub error ($)

