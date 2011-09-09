#!/usr/bin/perl -w

use strict;
#use Data::Dumper;
use Email::Simple;

use MailArchive::Config;
use MailArchive::Email;
use MailArchive::Util;

# Return the earliest matching Received: email header from the list, or undef if there is no
# matching header.
sub last_matching_host ($$)
{
	my $list = shift;
	my $regex = shift;

	for (reverse @$list) {
		return $_ if $_->[0] =~ /$regex/;
	}
	return undef;
}


my $text = read_stdin();
my $email = Email::Simple->new($text);
my @received = $email->header("Received");
#my @received = grep { contains_local_host $_ } $email->header("Received");
#print Dumper(@received);
my $list = received_hosts(@received);
#my $domain = 'gear\.dyndns\.org';
#my $domain = '10\.';
#my $domain = '^[^\.]*$';
#my $entry = last_matching_host($list, $domain);

for my $entry (reverse @$list) {
	printf "%s %s\n", scalar localtime parse_date($entry->[1]), $entry->[0]
		if defined $entry and is_local_host($entry->[0]);
}

