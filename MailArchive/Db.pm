#!/usr/bin/perl -w
#
# Databases routines for mail archiver
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

package MailArchive::Db;

# module setup
use strict;
use warnings;
use Exporter;
use vars qw($VERSION @ISA @EXPORT); # @EXPORT_OK); # %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(

	check_file
	add_file

);
#@EXPORT_OK   = qw(mysub1);
#%EXPORT_TAGS = ( DEFAULT => [qw(&mysub2)] );

# code dependencies
use DBI;

use MailArchive::Config;
use MailArchive::Log;

my $select;
my $insert;
my $dbh;

sub add_file ($$)
{
	init() unless defined $insert;

	my ($file, $checksum) = @_;
	debug "add_file $file, $checksum";
	$insert->execute($file, $checksum)
		or error "Cannot execute insert statement: " . $dbh->errstr;
#	while (my $ref = $insert->fetchrow_hashref()) {
#		print "Found a row: id = $ref->{'id'}, name = $ref->{'name'}\n";
#	}
	$insert->finish();
}

sub check_file ($$)
{
	init() unless defined $select;

	my ($file, $checksum) = @_;
	debug "check_file $file, $checksum";
	$select->execute($checksum)
		or error "Cannot execute select statement: " . $dbh->errstr;
	my @results;
	while (my $ref = $select->fetchrow_hashref()) {
		#print "Found a row: filename = $ref->{'filename'}, checksum = $ref->{'checksum'}\n";
		push @results, $ref->{'filename'};
	}
	$select->finish();
	return @results;
}

sub open_db ()
{
	my $dbconnect	= getconfig('dbconnect');
	my $username	= getconfig('dbuser');
	my $password	= getconfig('dbpass');
	debug "Opening database connection";
	$dbh = DBI->connect($dbconnect, $username, $password)
		or error "Cannot open connection $dbconnect: " . $DBI::errstr;
}

sub create_tables ()
{
	debug "Creating table (if required)";
	$dbh->do("
		create table if not exists fileinfo (
			filename varchar(500) unique,
			checksum varchar(500),
			time     timestamp,
			primary key (filename, checksum)
		)
	")
		or die "Cannot create table: " . $dbh->errstr;
}

sub create_statements ()
{
	debug "Creating select statement";
	$select = $dbh->prepare("
		select filename, checksum
		from fileinfo
		where checksum = ?
		order by time
	")
		or error "Cannot create select statement: " . $dbh->errstr;
	debug "Creating insert statement";
	$insert = $dbh->prepare("
		insert into fileinfo (filename, checksum) values (?, ?)
	")
		or error "Cannot create insert statement: " . $dbh->errstr;
}

sub init ()
{
	#my $basedir = shift;
	open_db();
	create_tables();
	create_statements();
}

1;	# file must return true - do not remove this line

