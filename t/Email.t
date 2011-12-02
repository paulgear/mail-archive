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
use Test::More tests => 1;
use strict;
use warnings;

use_ok( 'MailArchive::Email' );

#	clean_subject
#	concatenate_headers
#	dump_email_address
#	dump_email_addresses
#	get_local_received_date
#	is_local
#	send_error

#sub clean_subject ($$)
#	my ($subject, $projnum) = @_;
#	debug "subject (pre-clean) = $subject";
#	$subject =~ s/((Emailing|FW|Fwd|Re|RE): ?)*//g;	# delete MUA noise
#	$subject =~ s/($projnum\s*)*//g;		# delete references to the project number
#	$subject =~ s/[\\<>*|?:]+//g;			# delete samba reserved characters
#	$subject =~ s/\// /g;				# replace / with space
#	$subject =~ s/\s+/ /g;				# compress whitespace
#	$subject =~ s/^\s+//g;				# delete leading whitespace
#	$subject =~ s/\s+$//g;				# delete trailing whitespace
#	$subject = "NO SUBJECT" if $subject =~ /^$/;	# add a subject if none exists

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

