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
my $lock;
my $unlock;

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
		or dberror "executing insert file";
}

sub check_file ($$)
{
	init() unless defined $select;

	my ($file, $checksum) = @_;
	my @results;
	if ($select->execute($checksum)) {
		while (my $ref = $select->fetchrow_hashref()) {
			#print "Found a row: filename = $ref->{'filename'}, checksum = $ref->{'checksum'}\n";
			push @results, $ref->{'filename'};
		}
	}
	else {
		dberror "executing select file";
	}
	return @results;
}

# This function works as a mutex to prevent multiple copies of mail-archive checking for the
# existence of a message id in parallel.  Overall logic:
# - lock messages table
# - check if message id exists in messages table
# - if not, add it
# - unlock messages table
# This prevents two parallel instances of mail-archive accessing the messages table, which is
# important if two identical message arrive in quick succession (often due multiple recipients
# on the same message being archived).
sub check_message ($$$)
{
	init() unless defined $message_select;
	my ($id, $checksum, $project) = @_;
	my $ret;
	if ($lock->execute()) {
		debug "Searching for $id, $checksum";
		if ($message_select->execute($id)) {
			while (my @row = $message_select->fetchrow_array()) {
				$ret = \@row;
				debug "Got result: @row";
				last;
			}
			unless (defined $ret) {
				debug "Inserting $id, $checksum, $project";
				$message_insert->execute($id, $checksum, $project)
					or dbwarning "executing message insert";
			}
		}
		else {
			dbwarning "executing message select";
		}
		$unlock->execute()
			or dbwarning "executing unlock tables";
	}
	else {
		dbwarning "executing lock tables";
	}
	return $ret;
}

sub remove_file ($)
{
	init() unless defined $delete;

	my $file = shift;
	$delete->execute($file)
		or dbwarning "executing fileinfo delete - please delete $file entry manually";
}

# Remove a previously-added message id record.  Used for smart-drop messages which are discarded.
sub remove_message ($$$)
{
	init() unless defined $message_select;
	my ($id, $checksum, $project) = @_;
	if ($lock->execute()) {
		$message_delete->execute($id, $checksum, $project)
			or dbwarning "executing message delete - please delete ($id, $checksum, $project) manually";
		$unlock->execute()
			or dbwarning "executing unlock tables";
	}
	else {
		dbwarning "executing lock tables - please delete ($id, $checksum, $project) manually";
	}
}

sub open_db ()
{
	my $dbconnect	= getconfig('dbconnect');
	my $username	= getconfig('dbuser');
	my $password	= getconfig('dbpass');
	debug "Opening database connection";
	$dbh = DBI->connect($dbconnect, $username, $password)
		or fatal "Cannot open connection $dbconnect: " . $DBI::errstr;
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
		or dberror "creating file select";
	$insert = $dbh->prepare("
		insert into fileinfo (filename, checksum) values (?, ?)
	")
		or dberror "creating file insert";
	$delete = $dbh->prepare("
		delete from fileinfo where filename = ?
	")
		or dberror "creating file delete";
	$message_select = $dbh->prepare("
		select id, checksum, project, time
		from messages
		where id = ?
	")
		or dberror "creating message select";
	$message_delete = $dbh->prepare("
		delete from messages where id = ? and checksum = ? and project = ?
	")
		or dberror "creating message delete";
	$message_insert = $dbh->prepare("
		insert into messages (id, checksum, project) values (?, ?, ?)
	")
		or dberror "creating message insert";
	$lock = $dbh->prepare("lock tables messages write")
		or dberror "creating lock tablesstatement";
	$unlock = $dbh->prepare("unlock tables")
		or dberror "creating unlock tables statement";
}

sub init ()
{
	#my $basedir = shift;
	open_db();
	create_tables();
	create_statements();
}

1;	# file must return true - do not remove this line
