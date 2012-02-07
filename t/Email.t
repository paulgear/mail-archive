#!/usr/bin/perl -w
#
# Email processing tests for mail archiver
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
use Test::More tests => 121;
use strict;
use warnings;

use_ok( 'MailArchive::Email' );

# TODO:
#	checksum_parts
#	collect_names
#	collect_parts
#	condense_parts
#	dump_email_address
#	dump_email_addresses
#	dump_part
#	get_local_received_date
#	is_local
#	send_error

#sub clean_subject ($$)
print "Testing clean_subject\n";

sub test_clean_subject ($)
{
	my $projnum = shift;
	my $num = 'QB987654';

	is(clean_subject(undef, $projnum), undef);
	is(clean_subject("", $projnum), "");
	is(clean_subject("    ", $projnum), "");
	is(clean_subject("Hello world", $projnum), "Hello world");
	is(clean_subject("\t  Hello world", $projnum), "Hello world");
	is(clean_subject("Hello world\r\n", $projnum), "Hello world");
	is(clean_subject("Hello world:Hello world\r\n", $projnum), "Hello worldHello world");
	is(clean_subject("    Hello    \t world  \n", $projnum), "Hello world");

	# some semi-real-world tests
	is(clean_subject("[MY1234-Testing] Need a flurble coordinator/s for A-123 on Tuesday", $projnum),
		"[MY1234-Testing] Need a flurble coordinator s for A-123 on Tuesday");
	is(clean_subject("Status report (was Re: Join my network on LinkedIn)", $projnum),
		"Status report (was Join my network on LinkedIn)");
	is(clean_subject("Disallowed attachments in **Fwd: Re: http://youtube.com video issues**", $projnum),
		"Disallowed attachments in http youtube.com video issues");
	is(clean_subject("Fwd: Long lead-Time for Components - PLEASE READ - IMPORTANT!", $projnum),
		"Long lead-Time for Components - PLEASE READ - IMPORTANT!");
	is(clean_subject("RE: Setting up VLANs, LAG's and routing on our Cisco switches", $projnum),
		"Setting up VLANs, LAG's and routing on our Cisco switches");

	if (!defined $projnum || $projnum ne $num) {
		is(clean_subject("  $num/Hello world", $projnum), "$num Hello world");
		is(clean_subject(" Emailing: Hello world ($num)", $projnum), "Hello world ($num)");
	}
	else {
		is(clean_subject("  $num/Hello world", $projnum), "Hello world");
		is(clean_subject(" Emailing: Hello world ($num)", $projnum), "Hello world ()");
	}

	unless (defined $projnum) {
		# We expect the same results as a non-whitespace projnum,
		# but this avoids undef warnings from the test suite.
		is(clean_subject("  /Hello world", $projnum), "Hello world");
		is(clean_subject(" Emailing: Hello world ()", $projnum), "Hello world ()");
		is(clean_subject(" Emailing: Hello world (  )", $projnum), "Hello world ( )");
		is(clean_subject("Re:  Testing 123", $projnum), "Testing 123");
		is(clean_subject("Re:  - yet another test", $projnum), "- yet another test");
	}
	elsif ($projnum =~ /^\s+$/) {
		is(clean_subject("  $projnum/Hello world", $projnum), "Hello world");
		is(clean_subject(" Emailing: Hello world ($projnum)", $projnum), "Hello world ( )");
		is(clean_subject(" Emailing: Hello world (  $projnum)", $projnum), "Hello world ( )");
		is(clean_subject("Re: $projnum Testing 123", $projnum), "Testing 123");
		is(clean_subject("Re: $projnum - yet another test", $projnum), "- yet another test");
	}
	else {
		is(clean_subject("  $projnum/Hello world", $projnum), "Hello world");
		is(clean_subject(" Emailing: Hello world ($projnum)", $projnum), "Hello world ()");
		is(clean_subject(" Emailing: Hello world (  $projnum)", $projnum), "Hello world ( )");
		is(clean_subject("Re: $projnum Testing 123", $projnum), "Testing 123");
		is(clean_subject("Re: $projnum - yet another test", $projnum), "- yet another test");
	}
}

test_clean_subject(undef);
test_clean_subject('');
test_clean_subject('  ');
test_clean_subject('QB1234');
test_clean_subject('QB123456');
test_clean_subject('FN1234567890');

# concatenate headers in an array into a single string
#sub concatenate_headers (@)

#sub dump_email_address ($$)
#	my ($label, $address) = @_;

#sub dump_email_addresses ($@)
#	my $label = shift;

# Given a list of received headers, return the earliest date the message was received by a
# server in localdomains.
#sub get_local_received_date (@)
#	my $list = received_hosts(@_);

# Return the date in the given Received: email header
#sub get_received_date ($)

# Return the hostname in the given Received: email header.
#sub get_received_host ($)
#	my $str = shift;

# determine whether the given email address(s) matches the list of local domains
#sub is_local (@)
#	for my $addr (@_) {

# determine whether the given string(s) contain(s) a hostname which matches the list of local
# domains
#sub is_local_host (@)
#	for my $str (@_) {

# Parse the given date string and return it in standard Unix time format.
# Return undef if the date cannot be parsed.
#sub parse_date ($)
#	my $time = str2time($_[0]);

# Parse the given list of Received: email headers, returning a pointer to an array of pointers
# to arrays containing the received host, the date of receipt (as a literal string from the
# original header), and the original header itself.
#sub received_hosts (@)

# send a reply to the given email
#sub send_error ($$$)
#	my $msg = shift;		# the email message to bounce
#	my $diag = shift;		# message to send as a diagnostic
#	my $origto = shift;		# original message recipients

