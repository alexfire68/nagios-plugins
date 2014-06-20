#!/usr/bin/perl -w

#########################################################################
# 	Name: 		check_queue.pl					#
#	Author: 	Alexis Rapior					#
#	Mail:		alex.rapior@gmail.com				#
#	Date:		16 june 2014					#
#	Version:	1.0						#
#									#
#	Description:	This program established an SSH connection to a	#
#			mail server in order to monitor the number	#
#			of messages in the mailq either general or 	#
#			either per domain (see --help for more).	#
#			This program has been written to be executed	#
#			from a Red Hat/CentOS based system. It may not  #
#			work correctly with a Debian based system.	#
#									#
#	/!\ Important: 	The $mailq_bin must correspond			#
#			to your MTA (sendmail, postfix...). Adjust	#
#			this variable in function of your environment.	#
#									#
#	Bugs:		Please send any bugs or comments to		#
#			<alex.rapior@gmail.com>.			#
#########################################################################

use strict;
use warnings;

use Math::BigInt::GMP; #enhance speed in SSH request
use Net::SSH::Perl;
use Scalar::Util qw(looks_like_number);
use Getopt::Long;
Getopt::Long::Configure("no_ignorecase");
Getopt::Long::Configure("no_auto_abbrev");

#### variable declaration ###

#--script param
my $warning="90";
my $critical="95";
my $host=undef;
my $domain=undef;
my $print_help=0;
my $print_version=0;
my $print_licence=0;
my $print_all=0;
my $verbose=0;
my $identity_file=".ssh/id_rsa";
#--end script param

#--ssh param
my $user="root";
my $password=undef;
my $port=22;
#my $mailq_bin="/usr/bin/mailq"; 			#sendmail style mailq
#my $mailq_bin="/usr/sbin/postqueue -p"; 		#postfix style mailq
my $mailq_bin="/opt/pmx6/postfix/sbin/postqueue -p";	#personalised mailq command
my $command=undef;
my $value=undef;
#--end ssh param

my $version = "1.0";
my $licence = "This program is free software, you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 2 of the License.\n";

### end variable declaration ###


GetOptions(	"a|all"		=> \$print_all,
		"c|critical=i"	=> \$critical,
		"d|domain=s" 	=> \$domain,
		"h|help"	=> \$print_help,
		"H|host=s" 	=> \$host,
		"i|identity=s"	=> \$identity_file,
		"l|licence"	=> \$print_licence,
		"p|port=i"	=> \$port,
		"u|user=s"	=> \$user,
		"v|verbose"	=> \$verbose,
		"V|version"	=> \$print_version,
		"w|warning=i"	=> \$warning)
or die("Error in command line arguments\n");

sub help(){
print  "\n$licence
##########################################
#	Alexis Rapior - 2014		 #
#	Bugs to <alexis.rapior\@uha.fr>   #	
#	Version $version			 #
##########################################

Usage:
$0
	-a (--all)	Print the number of messages in queue
	-c (--critical)	Number of messages that will cause an error (default 95)
	-d (--domain)	Domain name to monitore (required)
	-h (--help)	Usage help
	-H (--hostname)	Hostname to query (required)
	-i (--identity) SSH identity file (default .ssh/id_rsa)
	-l (--licence)	Print the licence of this program
	-p (--port)	SSH port number (default 22)
	-u (--user)	SSH user (default root)
	-v (--verbose)	Add verbosity to the output (only one level)
	-V (--version)	Print the version of this program
	-w (--warning)	Number of messages that will cause a warning (default 90)\n"
}

sub execute_remote_command($){
	#SSH constructor
	if ($verbose==1){print "\t--> Connecting to $user\@$host:$port, identity file $identity_file.\n";}
	my $ssh=Net::SSH::Perl->new($host, identity_files=>[$identity_file], port=>$port, protocol=>2, privileged=>0);
	
	#SSH connection
	$ssh->login($user) or die("Can't connect to $host\n");
	#$ssh->login($user, $password) or die("Can't connect to $host\n");
	
	#SSH command
	if ($verbose==1){print "\t--> Executing the remote command:\n$_[0]\n\n";}
	my($stdout, $sterr, $exit)=$ssh->cmd("$_[0]"); #send the argument passed to the function
	return $value=$stdout;
}

### begin arguments testing ###

#catch help message
if ($print_help==1) {
	if ($verbose==1){print "--> Printing help message.\n";}
	help();
	exit 3;
}

#catch licence message
if ($print_licence==1) {
	if ($verbose==1){print "--> Printing the licence.\n";}
	print "$licence";
	exit 3;
}

#catch version message
if ($print_version==1) {
	if ($verbose==1){print "--> Printing the program version.\n";}
	print "$version\n";
	exit 3;
}

#check if host and domain are defined
if ($print_all==0){
	if (!defined $host or !defined $domain){
		print "Host and Domain values and must be defined! (try -h for help)\n";
		exit 3;
	}
}
elsif ($print_all==1){
	if (!defined $host){
		print "Host value must be defined! (try -h for help)\n";
		exit 3;
	}
}	

#check if warning < critical
if ($critical<$warning){
	print "Critical value must be greater than Warning value! (try -h for help)\n";
	exit 3;
}

#check if print_all is defined
if ($print_all==1){
	$command="$mailq_bin | grep ^[^A-Z\\|0-9\\] | grep -v \"(\" | grep \"@\" | wc -l";
}
else {
	$command="$mailq_bin | grep ^[^A-Z\\|0-9\\] | grep -v \"(\" | grep \"@\" | cut -d@ -f2 | sort | uniq -c | sort -nr \| awk \'\$2 == \"$domain\"\' | awk \'\{print \$1\}\'";

}

### end arguments testing ###

#execute the remote command
if ($verbose==1){print "\n-->Executing the subroutine execute_remote_command\n";}
execute_remote_command($command);

#if no line ise returned from command, no mails in mailq
if (!defined $value){
	#value not defined, should be equals to 0?
	$value=0;
}

#if value is not a number
if (!looks_like_number $value){
	print "Unknown";
	exit 3;
}
else {
	chomp $value;
}

if ($value<$warning and $value<$critical){
	print "OK - $value mails in queue | queue=$value;$warning;$critical;0;\n";
	exit 0;
}
elsif ($value>=$warning and $value<$critical){
	print "Warning - $value mails in queue | queue=$value;$warning;$critical;0;\n";
	exit 1;
}
elsif ($value>=$critical){
	print "Critical - $value mails in queue | queue=$value;$warning;$critical;0;\n";
	exit 2;
}
