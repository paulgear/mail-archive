#!/usr/bin/perl -w
#
# Error sending functions for mail archiver
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

package MailArchive::Error;

# module setup
use strict;
use warnings;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK); # %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(

	send_admin_error
	send_error_email

);
#@EXPORT_OK   = qw(mysub1);
#%EXPORT_TAGS = ( DEFAULT => [qw(&mysub2)] );

# code dependencies
use Email::Sender::Simple qw(sendmail);
use Email::Simple;

use MailArchive::Config;

# determine whether the given address is in the given header
sub check_email_address ($$)
{
	my $header = shift;
	my $address = shift;
	#debug "header = $header";
	#debug "address = $address";
	my @addrs = Email::Address->parse($header);
	#debug "addrs = @addrs";
	my @match = grep { $_->address eq $address } @addrs;
	#debug "match = @match";
	return $#match > -1;
}

# ensure $ENV{'PATH'} is not tainted
sub untaint_path ()
{
	$ENV{'PATH'} = '/usr/sbin:/usr/bin:/sbin:/bin';
}

sub send_error_email ($$)
{
	my $msg = shift;
	my $diag = shift;

	my $header = getconfig('status-header');
	$msg->header_set( $header => $diag );

	my $errsubj = getconfig('error-subject');
	$msg->header_set( 'Subject' => $errsubj );

	# make sure we don't create a mail loop by sending to ourselves
	my $to = $msg->header('To');
	if (check_email_address($to, getconfig('archiver-email'))) {
		$msg->header_set( 'To' => getconfig('admin-email') );
	}

	$to = $msg->header('To');

	untaint_path();
	sendmail($msg);
	exit 0;
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

1;	# file must return true - do not remove this line
