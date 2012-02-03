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

	checksum_parts
	clean_subject
	collect_names
	collect_parts
	condense_parts
	dump_email_address
	dump_email_addresses
	dump_part
	get_local_received_date
	is_local
	send_error

);
@EXPORT_OK   = qw( );

# code dependencies
use Date::Parse;
use Email::MIME;
use Email::Reply;
use Email::Simple;

use MailArchive::Config;
use MailArchive::Error;
use MailArchive::Log;
use MailArchive::Util;

# prototypes
sub parse_date ($);

sub clean_subject ($$)
{
	my ($subject, $projnum) = @_;
	debug "subject (pre-clean) = $subject";
	$subject =~ s/((Emailing|FW|Fwd|Re|RE): ?)*//g;	# delete MUA noise
	$subject =~ s/($projnum\s*)*//g;		# delete references to the project number
	$subject =~ s/[\\<>*|?:]+//g;			# delete samba reserved characters
	$subject =~ s/\// /g;				# replace / with space
	$subject =~ s/\s+/ /g;				# compress whitespace
	$subject =~ s/^\s+//g;				# delete leading whitespace
	$subject =~ s/\s+$//g;				# delete trailing whitespace
	#$subject = "NO SUBJECT" if $subject =~ /^$/;	# add a subject if none exists
	debug "subject (post-clean) = $subject";
	return $subject;
}

# Given an array of hash pointers to message parts, collect all of the filenames and return the
# length of the longest filename.  Compensate for stupid email systems (e.g. MS Exchange 6.5)
# which provide an entire MS-DOS path as the attachment name.
sub collect_names (@)
{
	my $max = 0;
	my %names;
	for my $p (@_) {
		my $name = $p->{'part'}->filename;
		my $disp = $p->{'part'}->header('Content-Disposition');
		if (defined $name) {
			# name is supplied in the message
			if ($name =~ /^[A-Z]:\\/) {
				# nasty MS-DOS path mangling - delete everything up to and
				# including the final backslash
				$name =~ s/(.*)\\([^\\]+)/$2/;
			}
		}
		elsif (defined $disp) {
			# content disposition supplied, but no name: make one up
			$name = $p->{'part'}->filename(1);
		}
		else {
			# skip parts with no name or content disposition
			next;
		}

		# note any name clashes
		if (exists $names{$name}) {
			$p->{'nameclash'} = $names{$name};
		}
		else {
			$names{$name} = $p;
		}

		# save the name and note max length
		$p->{'name'} = $name;
		$max = length($name) if length($name) > $max;
	}
	return $max;
}

# return an array of hash pointers containing all message parts
# checksum each part along the way
sub collect_parts
{
	my ($msg, $level) = @_;
	$level = 0 unless defined $level;

	my @parts;
	limit_recursion($level) or return @parts;

	for my $p ($msg->parts) {
		# get checksum for the part
		my $cksum = get_checksum($p->body);

		# add the part to our array
		push @parts, { part => $p, level => $level, checksum => $cksum };

		# recurse if necessary
		if (defined $p->content_type and $p->content_type =~ /^message\//) {
			my $sp = Email::MIME->new($p->body_raw);
			if (defined $sp and $sp->subparts > 0) {
				push @parts, collect_parts($sp, $level + 1);
			}
		}
	}
	return @parts;
}

# return the supplied list of message parts, with any duplicate parts eliminated
sub condense_parts (@)
{
	my @parts;
	my %cksums;
	for my $p (@_) {
		next if exists $cksums{$p->{'checksum'}};
		$cksums{$p->{'checksum'}} = $p->{'part'}->filename;
		push @parts, $p;
	}
	return @parts;
}

sub dump_email_address ($$)
{
	my ($label, $address) = @_;
	my @attrs = map { $address->$_ } qw(name user host);
	debug(sprintf "%s: %s <%s@%s>", $label, @attrs);
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

sub dump_part
{
	my $part = shift;
	my $indent = shift;
	$indent = 0 unless defined $indent;
	my $prefix = "    " x $indent;
	my $disp = $part->header('Content-Disposition');
	#return if defined $disp and $disp =~ /^attach/;
	#printf "%s----\n", $prefix;
	print "\n";
	printf "%stype = %s\n", $prefix, $part->content_type;
	printf "%sdisp = %s\n", $prefix, $disp
		if defined $disp;
	printf "%sname = %s\n", $prefix, $part->filename(1);
	printf "%ssubparts = %d\n", $prefix, scalar $part->subparts
		if scalar $part->subparts > 0;
}

# Given a list of received headers, return the earliest date the message was received by a
# server in localdomains.
sub get_local_received_date (@)
{
	my $list = received_hosts(@_);
	return undef unless defined $list;
	for my $entry (reverse @$list) {
		next unless defined $entry;
		debug sprintf("Received entry: %s %s\n", scalar localtime parse_date($entry->[1]),
			$entry->[0]);
		return parse_date($entry->[1]) if is_local_host($entry->[0]);
	}
	return undef;
}

# Return the date in the given Received: email header
sub get_received_date ($)
{
	my $str = shift;
	my @date = $str =~ /((?:\S+,\s+)?\d+\s+\S+\s+\d+\s+\d+:\d+:\d+(?:\s+[+-]\d+)?(?:\s+\(?\S+\)?)?)/;
	return $#date == 0 ? $date[0] : "";
}

# Return the hostname in the given Received: email header.
sub get_received_host ($)
{
	my $str = shift;
	my @host = $str =~ /by\s+(\S+)/;
	return $#host == 0 ? $host[0] : "";
}

# determine whether the given email address(s) matches the list of local domains
sub is_local (@)
{
	my @localdomains = @{getconfig('localdomains')};
	debug "localdomains = @localdomains";
	for my $addr (@_) {
		my $dom = $addr->host;
		debug("dom = $dom, addr = " . $addr->format);
		my @local = grep {$_ eq $dom} @localdomains;
		debug "local = @local";
		debug("Email is " . ($#local > -1 ? "local" : "NOT local"));
		return 1 if $#local > -1;
	}
	return 0;
}

# determine whether the given string(s) contain(s) a hostname which matches the list of local
# domains
sub is_local_host (@)
{
	my @localdomains = grep { !/^localhost/ } @{getconfig('localdomains')};
	debug "localdomains = @localdomains";
	for my $str (@_) {
		my @local = grep {$str =~ /$_$/} @localdomains;
		debug "$str is" . ($#local > -1 ? "" : " NOT") . " local (@local)";
		return 1 if $#local > -1;
	}
	return 0;
}

# Parse the given date string and return it in standard Unix time format.
# Return undef if the date cannot be parsed.
sub parse_date ($)
{
	my $time = str2time($_[0]);
	return defined $time ? $time : undef;
}

# Parse the given list of Received: email headers, returning a pointer to an array of pointers
# to arrays containing the received host, the date of receipt (as a literal string from the
# original header), and the original header itself.
sub received_hosts (@)
{
	my $hosts;
	my $i = 0;
	for my $r (@_) {
		chomp $r;
		#print "Received |$r|\n";
		my $host = get_received_host($r);
		my $date = get_received_date($r);
		if ($date ne "") {
			$hosts->[$i++] = [ $host, $date, $r ];
		}
	}
	return $hosts;
}

# send a reply to the given email
sub send_error ($$$)
{
	my $msg = shift;		# the email message to bounce
	my $diag = shift;		# message to send as a diagnostic
	my $origto = shift;		# original message recipients

	debug "Replying with: $diag";
	my $footer = "
The attached email has not been archived.

(This notice applies to mail archiving only and has no bearing
on delivery to other recipients of the original message.)
";
	my $reply = reply(
		to		=> $msg,
		from		=> getconfig('archiver-email'),
		attach		=> 1,
		quote		=> 0,
		body		=> "$diag\n$footer\n",
	);

	# Prevent all non-local addresses from receiving this reply.
	debug "checking reply recipients";
	my $to = $reply->header('To');
	my @to = Email::Address->parse($to);
	debug "reply to = @to";

	# remove non-local addresses from each list
	my @tolist = grep { is_local($_) } @to;
	debug "reply to (filtered) = @tolist";
	my @origtolist = grep { is_local($_) } @$origto;
	debug "orig to (filtered) = @origtolist";

	# Use the reply's To address, or the original message's To addresses, and if no
	# local addresses can be found in either list, use the admin address as the error
	# recipient.
	my @replyto;
	if ($#tolist > -1) {
		@replyto = @tolist;
	}
	elsif ($#origtolist > -1) {
		@replyto = @origtolist;
	}
	else {
		@replyto = getconfig('admin-email');
	}

	debug "sending bounce to @replyto";
	$reply->header_set( To => @replyto );
	send_error_email($reply, $diag);
}

1;	# file must return true - do not remove this line
