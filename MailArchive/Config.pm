#!/usr/bin/perl -w
#
# Configuration routines for mail archiver
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

package MailArchive::Config;

# module setup
use strict;
use warnings;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK); # %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(

	getconfig
	setconfig

);
@EXPORT_OK   = qw( );

# defaults for configurable variables - see config.pl for description
our %config = (

	'admin-email'		=> 'root@localhost',
	'archiver-email'	=> 'mailarchive@localhost',
	'dbconnect'		=> 'DBI:mysql:database=mailarchive',
	'dbpass'		=> 'mailarchive',
	'dbuser'		=> 'mailarchive',
	'error-subject'		=> 'Mail Archive Error',
	'localdomains'		=> [ 'localhost' ],
	'projnum-regex'		=> '\b(FN\d{6})\b',
	'projnum-split-regex'	=> '^FN(\d\d)(\d\d)(\d\d)$',
	'recursion-level'	=> 99,
	'searchpath'		=> [ '/', '/files' ],
	'smart-outgoing'	=> 0,
	'split'			=> 1,
	'subject-override'	=> 1,
	'status-header'		=> 'X-MailArchive-Status',

);

# pull in the site settings
require "config.pl";

sub getconfig ($)
{
	return $config{$_[0]};
}

sub setconfig ($$)
{
	$config{$_[0]} = $_[1];
}

1;	# file must return true - do not remove this line

