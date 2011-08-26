#!/usr/bin/perl -w
#
# Logging functions for mail archiver
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

package MailArchive::Log;

# module setup
use strict;
use warnings;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK); # %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(

	debug
	error
	getdebug
	setdebug

);
@EXPORT_OK   = qw(init);
#%EXPORT_TAGS = ( DEFAULT => [qw(&mysub)] );

# code dependencies
use File::Basename;
use Unix::Syslog qw(:macros :subs);

use MailArchive::Config;

my $PROG = "";
my $DEBUG;

sub init ($)
{
	my $prog = shift;	# get rid of module name argument - why is this needed?
	$prog = basename shift;	# get argument
	$prog =~ m/^(\S+)$/;	# untaint
	$PROG = $1;
	setdebug(-t 1);
	openlog $prog, LOG_PID | LOG_CONS, LOG_USER;
}

sub getdebug ()
{
	return $DEBUG;
}

sub setdebug ($)
{
	$DEBUG = $_[0] ? 1 : 0;
	#print STDERR "$PROG: debug is " . ($DEBUG ? "on" : "off") . "\n";
}

sub debug ($)
{
	print "$PROG: $_[0]\n" if $DEBUG;
	syslog LOG_INFO, "%s", $_[0];
}

# send a fatal error to the administrator
# FIXME: this really should be in MailArchive::Email, but i'm still trying to understand cyclic
# dependencies in perl modules
sub send_admin_error ($)
{
	my $diag = shift;
	my $msg = Email::Simple->create(
		header => [
			From    => getconfig('archiver-email'),
			To      => getconfig('admin-email'),
		],
		body => "Fatal error in mail archiver:\n\t$diag\nPlease check system logs.\n",
	);
	send_error_email($msg, $diag);
}

sub error ($)
{
	syslog LOG_CRIT, "%s", $_[0];
	send_admin_error($_[0]);
	exit 0;
}

1;	# file must return true - do not remove this line

