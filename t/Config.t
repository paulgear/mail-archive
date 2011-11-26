#/!/usr/bin/perl -w
#
# Configuration tests for mail archiver
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
use Test::More tests => 5;
use strict;
use warnings;

use_ok( 'MailArchive::Config' );

setconfig("test2", "1234");
is( getconfig("test2"), "1234", "getconfig after setconfig" );

ok( ! defined getconfig("test3"), "getconfig without setconfig" );

setconfig(undef, "1234");
is( getconfig(undef), undef, "getconfig undef" );

setconfig("test5", undef);
is( getconfig("test5"), undef, "getconfig undef data" );

