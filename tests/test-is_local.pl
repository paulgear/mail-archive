#!/usr/bin/perl -w

use lib ".";

use Email::Address;
use MailArchive::Email;

for (@ARGV) {
	my @addr = Email::Address->parse($_);
	print "address = $_\n";
	my $local = is_local(@addr);
	print "local = $local\n";
}
