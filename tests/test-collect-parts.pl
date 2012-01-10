#!/usr/bin/perl

use strict;
use warnings;

use Email::MIME;
use File::Path qw/remove_tree/;

use MailArchive::Email;
use MailArchive::Util;
#use Test::More tests => 1;

my $dir = "/tmp/asdf1234";
remove_tree $dir;
mkdir $dir or die "Cannot create $dir: $!";

#for (<tests/testemails/1307510413*>) {
#for (<tests/testemails/13075*>) {
for (@ARGV) {
	print "==== $_ ====\n";
	my $body = read_file($_);
	#ok(defined $body, "file read");

	my $msg = Email::MIME->new($body);
	#ok(defined $msg, "Email::MIME parse");
	#isa_ok($msg, 'Email::MIME');

	my @parts = collect_parts($msg);
	my $max = collect_names(@parts);
	#my @attachments = grep { defined $_->filename } @parts;

	#print "@parts\n" if @parts;
#	my @types = map { $_->content_type if defined $_->content_type } @parts;
#	printf "type [%s]\n", $_ for @types;
#	my @names = map { $_->filename if defined $_->filename && length($_->filename) > 0 } @parts;
#	print "$#names\n" if $#names > -1;

#	my $max = 0;
#	my @names;
#	for my $p (@parts) {
#		my $name = $p->{'part'}->filename;
#		my $type = $p->{'part'}->content_type;
#		$type = '' unless defined $type;
#		my $disp = $p->{'part'}->header('Content-Disposition');
#		my $save = 0;
#		if (!defined $name and defined $disp) {
#			#print "$_\n";
#			printf "NO NAME: type %s, disp %s\n", $type, $disp;
#			$save = 1;
#			$name = $p->{'part'}->filename(1);
#		}
#		else {
#			next;
#		}
#		#elsif (defined $name and defined $disp) {
#			#printf "%s: type %s, disp %s\n", $name, $type, $disp;
#			$save = 1;
#		#}
#		#$name = $p->{'part'}->filename(1) unless defined $name;
#		next unless defined $name;
#		save_file("$dir/$name", $p->{'part'}->body) if $save;
#		unless (defined $name) {
#			$name = $p->filename(1);
#			$type =~ s/;.*//;
#			printf "part %s (type %s, disp %s) has no name, using %s\n",
#				$p->{'num'}, $type, defined $disp ? $disp : "N/A", $name;
#			save_file("$dir/$name", $p->body);
#		}
#		push @names, $name;
#		$max = length($name) if length($name) > $max;
#	}

#	print "==== $_ ====\n";

	my $c1 = $#parts + 1;
	my $n1;
	my $n2;
#	printf "%d total\n", $c1;

	$n1 = $#parts;
	@parts = condense_parts @parts;
	$n2 = $#parts;
	my $dup = $n1 - $n2;
#	printf "%d duplicates\n", $dup if $dup > 0;

	$n1 = $#parts;
	@parts = grep { ! is_whitespace($_->{'part'}->body) } @parts;
	$n2 = $#parts;
	my $ws = $n1 - $n2;
#	printf "%d whitespace\n", $ws if $ws > 0;

	my @nonameparts = grep { ! defined $_->{'name'} } @parts;
	$n1 = $#parts;
	@parts = grep { defined $_->{'name'} } @parts;
	$n2 = $#parts;
	my $noname = $n1 - $n2;
#	printf "%d unnamed\n", $noname if $noname > 0;

	my @nonamecontentparts = grep { defined $_->{'part'}->header('Content-Disposition') }
		@nonameparts;
#	printf "%d unnamed but having Content-Disposition\n", $#nonamecontentparts + 1
#		if @nonamecontentparts;

	my $c2 = $#parts + 1;
	my $mismatch = $c1 - $ws - $dup - $noname - $c2;
	printf "%d MISMATCH\n", $mismatch unless $mismatch == 0;

	my @names = map { $_->{'name'} } grep { defined $_->{'name'} } @parts;
	for my $p (@parts) {
		next unless exists $p->{'name'};
		my $name = $p->{'name'};
		printf "%s %s %s\n", $name, length($name) == $max ? "*" : " ", $p->{'checksum'};
		if (exists $p->{'nameclash'}) {
			printf "\tclash with %s\n", $p->{'nameclash'}->{'checksum'};
		}
		else {
			my $fullpath = File::Spec->catfile($dir, $name);
			save_file($fullpath, $p->{'part'}->body);
		}
	}

	#print $msg->debug_structure;
}
