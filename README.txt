Overview
========

Mail-archive is an email archiver written in perl.  It is designed to
capture all email relating to client projects and file it together under
the project or file number.


Goals/Design
============

Notes on the overall design goals:

- Save disk space by saving each message part as a file, checking its SHA-256
  checksum against records in a database, comparing the files byte-by-byte if
  a match is found, and hard-linking the files in the filesystem if they are
  found to be identical.

- Work to specification for the client who commissioned it, but be flexible
  enough to adapt to other filing systems.


Installation
============

- Requires the following perl CPAN modules:
	DBI
	Digest
	Email::Abstract
	Email::Address
	Email::MIME
	Email::Reply
	Email::Sender
	File::Basename
	File::Compare
	File::Path
	File::Spec
	Getopt::Long
	Scalar::Util

- Assumes use of DBD::mysql DBI module, but other databases may work.  Patches
  providing compatibility with the database of your choice will be gratefully
  accepted.  :-)

- To install the required dependencies on Debian, use the following command:
	apt-get install \
		libdbd-mysql-perl \
		libdbi-perl \
		libdigest-perl \
		libemail-abstract-perl \
		libemail-address-perl \
		libemail-mime-perl \
		libemail-sender-perl \
		libfile-path-perl
  To install as a normal user on Ubuntu add sudo to the beginning of the above
  command.

- Install Email::Reply:
	cpan Email::Reply

- Install the files here in the home directory of a non-privileged user with
  permissions to write to your project directory.

- Edit .mailfilter and config.pl to suit your site.

- Create a database and allow the user to use it:
	mysql -p -u root
	(Enter root password for mysql)
	create database mailarchive;
	grant all privileges on database.* to 'user'@'host'
		identified by 'password';

  Usually the database name and user name are 'mailarchive' and the host is
  'localhost', but this is not mandatory - the database may be placed on any
  appropriate database host.  Mail-archive's database use is limited and it is
  unlikely to have high performance requirement unless you are feeding it with
  extremely high mail volumes or rates.

