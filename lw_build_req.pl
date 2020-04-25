#!/usr/bin/perl

#############################################################
#  Copyright (C) 2007 CIRT, Inc.
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation, version 2.
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
#  Sullo (sullo@cirt.net)
#  http://www.cirt.net/
#############################################################
# Version: 1.00, 2007-07-24
# This script takes in an HTTP header in a text file
# and writes the basic code to recreate the request in 
# a perl script using LibWhisker.
#
# The -r option is the HTTP request, in a file, to recreate
# The -p option sets an optional proxy in the LW code
# The -s option says to use SSL, and will turn default port to 443
# The -l option puts a loop template around the request portion of the output 
#############################################################

use strict;
my %options;
for (my $i=0;$i<=$#ARGV;$i++) 
	{
	 if ($ARGV[$i] eq "-l") { $options{l}=1; }
	 elsif ($ARGV[$i] eq "-s") { $options{s}=1; }
	 elsif ($ARGV[$i] eq "-r") { $i++; $options{r}=$ARGV[$i]; }
	 elsif ($ARGV[$i] eq "-p") { $i++; $options{p}=$ARGV[$i]; }
	 else { print "Invalid option: $ARGV[$i]\n"; exit; }
	}
if (!defined($options{r}) || ($options{r} eq '')) { usage(); }

open(IN,"<$options{r}") ||  usage(); 
my $req = join("",<IN>);
close(IN);

my %req_params=parse_request($req);
print build_lw_code(\%req_params);
exit;

sub build_lw_code
{
 my $p=shift;
 my %params=%$p;
 my $code= "#!/usr/bin/perl

#############################################################
# LibWhisker2 code automatically created by lw_build_req.pl #
#                    http://cirt.net/                       #
# Obtain the latest LibWhisker at wiretrip.net              #
#############################################################

use LW2;
# Create request
my \%request;
LW2::http_init_request(\\%request);
";

if ($options{s})
 {
   $code .= "if (!LW2::ssl_is_available()) { print \"ERROR: SSL not available.\\n\"; exit; }\n\n";
 }

$code .="
#############################################################
# Set parameters
";

 foreach my $i (keys %params)
  {
	my $ilc=lc($i);
	if ($ilc eq "host" )
	 	{ 
			my @hinfo=split(/:/,$params{$i});
			if ($hinfo[1] eq '') { $hinfo[1]=80; }
			$code .= "\t\$request{'whisker'}->{'host'}='$hinfo[0]';\n"; 
			$code .= "\t\$request{'whisker'}->{'port'}='$hinfo[1]';\n"; 
		}
	elsif ($ilc =~ /^(user-agent|cookie|(proxy-)?authorization)$/) 
	 	{ 
			$params{$i}=~s/'/\\'/g;
			$code .= "\t\$request{'$i'}='$params{$i}';\n"; 
		}
	else
		{
			$params{$i}=~s/'/\\'/g;
   			$code .= "\t\$request{'whisker'}->{'$ilc'}='$params{$i}';\n";
		}
  }
# proxy?
if ($options{p} ne '')
 {
   my ($host, $port) =split(/:/,$options{p});
   $code .= "\t\$request{'whisker'}->{'proxy_host'}='$host';\n";
   $code .= "\t\$request{'whisker'}->{'proxy_port'}='$port';\n";
 }

# ssl?
if ($options{s}) 
 {
   $code .= "\t\$request{'whisker'}->{'ssl'}=1;\n";
   $code =~ s/\'port\'\}=\'80\'/\'port\'\}=\'443\'/; # go back and change port from 80 to 443
 }


# loop?
if ($options{l})
{
 $code .="
#############################################################
# Loop for attacks
# Either replace the while statement with something meaningful,
# or put some code inside the loop to switch \$continue_loop
# to 0 after you've done what you want... otherwise you'll
# loop forever.
my \$continue_loop=1;
while (\$continue_loop)
	{
";

}

 $code .="
		#############################################################
		# Finish request build
		LW2::http_fixup_request(\\%request);

		#############################################################
		# Print request
		my \$display = LW2::dump('request', \\%request);
		print \$display;

		#############################################################
		# Make request
		LW2::http_do_request(\\%request,\\%result);

		#############################################################
		# Print results
		\$display = LW2::dump('result', \\%result);
		print \$display;
";

if ($options{l})
{
 $code .="
	}
";
}

$code .="
exit;
";

 return $code;
}

sub parse_request
{
 my $data_in = $_[0] || return;
 my %PARAMS;
 my @data=split(/\n/,$data_in);
 my $postdata=0;
 my $pdata;
 for (my $i=0;$i<=$#data;$i++)
  {
   if ($i eq 0)  # request line
	{ 
		my @b = split(/ /,$data[$i]);
		$PARAMS{'method'}=$b[0];
		$PARAMS{'uri'}=$b[1];
		$b[2] =~ s/^.*\///;
		$PARAMS{'version'}=$b[2];
		$i++;
	} 
   if ($data[$i] eq '') { $postdata=1; next; }
   if ($postdata) 
     { $pdata .= $data[$i];  next; }
   $data[$i] =~ m/(^\S+): (.*)$/;
   $PARAMS{$1}=$2;
  }
 if ($postdata) { $PARAMS{data}=$pdata; }
 return %PARAMS;
}

sub usage
{
 print "$0\n";
 print "\t-r request_file*\n";
 print "\t-p proxy:port\n";
 print "\t-l -- Add loop code template\n";
 print "\t-s -- Use SSL\n";
 print " * required option\n";
 print "\n (c) 2007 CIRT, Inc.\n";
 exit;
}
