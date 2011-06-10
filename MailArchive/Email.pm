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
	dump_email_address
	dump_email_addresses

);
@EXPORT_OK   = qw( );

# code dependencies
use MailArchive::Util;

sub clean_subject ($$)
{
	my ($subject, $projnum) = @_;
	debug "subject (pre-clean) = $subject";
	$subject =~ s/((Emailing|FW|Fwd|Re|RE): ?)*//g;	# delete MUA noise
	$subject =~ s/($projnum *)*//g;			# delete references to the project number
	$subject =~ s/[<>*|?:]+//g;			# delete samba reserved characters
	$subject =~ s/\s+/ /g;				# compress whitespace
	$subject =~ s/^\s*//g;				# delete leading whitespace
	$subject =~ s/\s*$//g;				# delete trailing whitespace
	debug "subject = $subject";
	return $subject;
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

1;	# file must return true - do not remove this line

