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

	add_file
	check_file
	check_message
	remove_message
	remove_file

);
#@EXPORT_OK   = qw(mysub1);
#%EXPORT_TAGS = ( DEFAULT => [qw(&mysub2)] );

# code dependencies
use DBI;

use MailArchive::Config;
use MailArchive::Log;

my $dbh;
my $select;
my $insert;
my $delete;
my $message_select;
my $message_insert;
my $message_delete;
my $lock_statement;
my $unlock_statement;

sub dberror ($)
{
	error "Database error $_[0]: " . $dbh->errstr;
}

sub dbwarning ($)
{
	warning "Database error $_[0]: " . $dbh->errstr;
}

sub add_file ($$)
{
	init() unless defined $insert;

	my ($file, $checksum) = @_;
	$insert->execute($file, $checksum)
		or error "Cannot execute insert statement: " . $dbh->errstr;
	$insert->finish();
}

sub check_file ($$)
{
	init() unless defined $select;

	my ($file, $checksum) = @_;
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

# This function works as a mutex to prevent multiple copies of mail-archive checking for the
# existence of a message id in parallel.  Overall logic:
# - lock messages table
# - check if message id exists in messages table
# - if not, add it
# - unlock messages table
# Use of RaiseError is just to make the database code less ugly. Without the exception handling
# it would require error handling at each step.
sub check_message ($$$)
{
	init() unless defined $message_select;
	my ($id, $checksum, $project) = @_;
	my $ret;
	if ($lock_statement->execute()) {
		debug "Searching for $id, $checksum";
		if ($message_select->execute($id)) {
			while (my @row = $message_select->fetchrow_array()) {
				$ret = \@row;
				debug "Got result: @row";
				last;
			}
			$message_select->finish() or dbwarning("closing message select");
			unless (defined $ret) {
				debug "Inserting $id, $checksum, $project";
				$message_insert->execute($id, $checksum, $project)
					or dbwarning("executing message insert");
			}
		}
		else {
			dbwarning("executing message select");
		}
		$unlock_statement->execute() or dbwarning("unlocking tables");
	}
	else {
		dbwarning("locking tables");
	}
	return $ret;
}

sub remove_file ($)
{
	init() unless defined $delete;

	my $file = shift;
	$delete->execute($file)
		or error "Cannot execute delete statement: " . $dbh->errstr;
	$delete->finish();
}

# Remove a previously-added message id record.  Used for smart-drop messages which are discarded.
sub remove_message ($$$)
{
	init() unless defined $message_select;
	my ($id, $checksum, $project) = @_;
	if ($lock_statement->execute()) {
		$message_delete->execute($id, $checksum, $project)
			or dbwarning("executing message delete - please delete ($id, $checksum, $project) manually");
		$unlock_statement->execute()
			or dbwarning("unlocking tables");
	}
	else {
		dbwarning("locking tables - please delete ($id, $checksum, $project) manually");
	}
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
	debug "Creating fileinfo table (if required)";
	$dbh->do("
		create table if not exists fileinfo (
			filename varchar(500) unique,
			checksum varchar(500),
			time     timestamp,
			primary key (filename, checksum)
		)
	")
		or die "Cannot create fileinfo table: " . $dbh->errstr;
	debug "Creating messages table (if required)";
	$dbh->do("
		create table if not exists messages (
			id        varchar(500),
			checksum  varchar(500),
			project   varchar(500),
			time      timestamp,
			primary key (id)
		)
	")
		or die "Cannot create messages table: " . $dbh->errstr;
#	debug "Creating references table (if required)";
#	$dbh->do("
#		create table if not exists references (
#			reference varchar(500),
#			messageid varchar(500),
#			time      timestamp,
#			primary key (reference, messageid)
#		)
#	")
#		or die "Cannot create references table: " . $dbh->errstr;
}

sub create_statements ()
{
	$select = $dbh->prepare("
		select filename, checksum
		from fileinfo
		where checksum = ?
		order by time
	")
		or error "Cannot create select statement: " . $dbh->errstr;
	$insert = $dbh->prepare("
		insert into fileinfo (filename, checksum) values (?, ?)
	")
		or error "Cannot create insert statement: " . $dbh->errstr;
	$delete = $dbh->prepare("
		delete from fileinfo where filename = ?
	")
		or error "Cannot create delete statement: " . $dbh->errstr;
	$message_select = $dbh->prepare("
		select id, checksum, project, time
		from messages
		where id = ?
	")
		or error "Cannot create message select statement: " . $dbh->errstr;
	$message_delete = $dbh->prepare("
		delete from messages where id = ? and checksum = ? and project = ?
	")
		or error "Cannot create message delete statement: " . $dbh->errstr;
	$message_insert = $dbh->prepare("
		insert into messages (id, checksum, project) values (?, ?, ?)
	")
		or error "Cannot create message insert statement: " . $dbh->errstr;
	$lock_statement = $dbh->prepare("lock tables messages write, fileinfo write")
		or error "Cannot create lock tables statement: " . $dbh->errstr;
	$unlock_statement = $dbh->prepare("unlock tables")
		or error "Cannot create unlock tables statement: " . $dbh->errstr;
}

sub init ()
{
	#my $basedir = shift;
	open_db();
	create_tables();
	create_statements();
}

1;	# file must return true - do not remove this line
