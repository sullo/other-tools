#!/bin/perl
###############################################################################
#  Copyright (C) 2009 CIRT, Inc.
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; version 2
#  of the License only.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
# Contact Information:
#  	Sullo (sullo@cirt.net)
#  	http://cirt.net/
#######################################################################
# This program recurses through a directory and gets the md5 hash of
# the *audio portion* any mp3 programs found. It will compare the hashes 
# from the 2nd (slave) directory to the 1st (master) and report duplicates.
#
# It will create a script file to move them to your desired location,
# and a text file of results.
#
# Note that it does not securely open files or any of that 'security'
# nonsense... it just clobbers them. Consider yourself warned.
#
# I take *no* liability for anything bad this program may or may not do.
# Use at your own risk.
#######################################################################

use MP3::Info;
use Digest::MD5 qw(md5_hex);
use File::Temp qw/ tempfile tempdir /;

# vars
my $verbose=1;
my $total=0;
my $duplicates=0;

# input
for (my $i=0; $i<5; $i++) { 
	if ($ARGV[$i] eq '') { usage(); }
	}
if (!-d $ARGV[4]) { die print "Error: <movetodir> is not a directory\n"; }
$ARGV[0] =~ s/\/$//;
$ARGV[1] =~ s/\/$//;

# open our result & script files
if ($ARGV[2] ne '') { open(RESULTS,">$ARGV[2]") || die print "Error opening result file '$ARGV[2]: $!\n"; }
if ($ARGV[3] ne '') { open(SCRIPT,">$ARGV[3]") || die print "Error opening script file '$ARGV[3]: $!\n"; }

# process the master -- save the data
my %hashes1 = gen_hashes($ARGV[0]);
# process the slave -- no data coming out
gen_hashes($ARGV[1], "slave");

# close our result file & scripts
close(RESULTS);
close(SCRIPT);

print "Total files: $total\nTotal dupes: $duplicates\n";

exit; 
####################################################
sub gen_hashes {
	my $dir = $_[0] || return;
	my $w = $_[1];
	my %holding;

	print "Generating hashes for '$dir'\n";
	foreach my $f (get_filelist($dir)) {
		if (!-f $f) { next; }  		# not a file
		if ($f !~ /\.mp3$/) { next; } 	# not an mp3
		$total++;
		$hash = get_hash(get_audio($f));
		if ($w eq 'slave') {
        		if ($hashes1{$hash} ne '') {  # duplicate hash
                		$duplicates++;
                		print "Duplicate: $f\n";
                		print RESULTS "$hash\n\t$hashes1{$hash}\n\t$f\n";
                		$f =~ s/\s/\\ /g;  # always practice safe moves!
                		print SCRIPT "mv $f /tmp\n";
                		}
			}
		else {
			print "$hash\t$f\n" if $verbose;
			$holding{$hash}=$f;
			}
		}
	return %holding;
	}

sub get_filelist {
	my $dir = $_[0] || return;
	if (!-d $dir) { return; }
	my @files = split(/\n/,`find '$dir'`); # this could be perl but... meh
  	return @files;	
	}

sub usage {
	print "$0 <dir1> <dir2> <resultfile> <resultscript> <movetodir>\n";
	print "\t<dir1> = mp3 source directory 1 (master)\n";
	print "\t<dir2> = mp3 source directory 2 (slave)\n";
	print "\t<resultfile> = plain text report (will be clobbered)\n";
	print "\t<resultscript> = shell script to move duplicates (will be clobbered)\n";
	print "\t<movetodir> = location to move duplicates set in <resultscript> (will be clobbered)\n";
	exit;
	}

sub get_audio {
	$filename = $_[0] || return;
	my $info = get_mp3info($filename);
	my $audio;
	open(MP3, $filename);
	read(MP3, $audio, $info->{SIZE}, $info->{OFFSET});
	close(MP3);
	return $audio;
	}

sub get_hash {
	my $data = $_[0] || return;
	return md5_hex($data);
	}

