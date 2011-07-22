#!/usr/bin/perl -w
#
# Email processing routines for mail archiver
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

package MailArchive::Email;

# module setup
use strict;
use warnings;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK); # %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(

	clean_subject
	concatenate_headers
	dump_email_address
	dump_email_addresses
	send_error

);
@EXPORT_OK   = qw( );

# code dependencies
use Email::Reply;
use Email::Sender::Simple qw(sendmail);

use MailArchive::Config;
use MailArchive::Util;

sub clean_subject ($$)
{
	my ($subject, $projnum) = @_;
	debug "subject (pre-clean) = $subject";
	$subject =~ s/((Emailing|FW|Fwd|Re|RE): ?)*//g;	# delete MUA noise
	$subject =~ s/($projnum\s*)*//g;		# delete references to the project number
	$subject =~ s/[\\<>*|?:]+//g;			# delete samba reserved characters
	$subject =~ s/\s+/ /g;				# compress whitespace
	$subject =~ s/^\s*//g;				# delete leading whitespace
	$subject =~ s/\s*$//g;				# delete trailing whitespace
	debug "subject (post-clean) = $subject";
	return $subject;
}

# concatenate headers in an array into a single string
sub concatenate_headers (@)
{
	my $header = "";
	while ($#_ > -1) {
		$header = $header . "$_[0]: $_[1]\n";
		shift;
		shift;
	}
	return $header;
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

# ensure $ENV{'PATH'} is not tainted
sub untaint_path ()
{
	$ENV{'PATH'} = '/usr/sbin:/usr/bin:/sbin:/bin';
}

# send a reply to the given email
sub send_error ($$$)
{
	my $msg = shift;		# the email message to bounce
	my $diag = shift;		# message to send as a diagnostic
	my $outgoing = shift;		# whether the message is outgoing

	debug "Dropping archive with reply message: $diag";
	my $reply = reply(
		to		=> $msg,
		from		=> getconfig('archiver-email'),
		attach		=> 1,
		quote		=> 0,
		body		=> <<__REPLY__);
Error archiving attached email:
$diag
__REPLY__
	$reply->header_set( Subject => 'Mail Archiver Error' );
	$reply->header_set( To => getconfig('admin-email') ) unless $outgoing;
	untaint_path();
	sendmail($reply);
	exit 0;
}

1;	# file must return true - do not remove this line
