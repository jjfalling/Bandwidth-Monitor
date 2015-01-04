#!/usr/bin/env perl
#****************************************************************************
#*   SNMP Bandwidth Monitor                                                 *
#*   Monitor bandwidth on a snmp compatible device in realtime              *
#*                                                                          *
#*   Copyright (C) 2015 by Jeremy Falling except where noted.               *
#*                                                                          *
#*   This program is free software: you can redistribute it and/or modify   *
#*   it under the terms of the GNU General Public License as published by   *
#*   the Free Software Foundation, either version 3 of the License, or      *
#*   (at your option) any later version.                                    *
#*                                                                          *
#*   This program is distributed in the hope that it will be useful,        *
#*   but WITHOUT ANY WARRANTY; without even the implied warranty of         *
#*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          *
#*   GNU General Public License for more details.                           *
#*                                                                          *
#*   You should have received a copy of the GNU General Public License      *
#*   along with this program.  If not, see <http://www.gnu.org/licenses/>.  *
#****************************************************************************
use strict;
use warnings; 
use Getopt::Long;
use Data::Dumper;

#Required modules
use Net::SNMP;
use Text::TabularDisplay;

########################################################################################
# User options: #
#################
#the default read community
my $opt_rcom='public';

########################################################################################
my $PROGNAME = "bandwidth_monitor.pl";
my $clear_string = `clear`; #used to clear the screen between polls

#Define oids we are going to use:
my %oids = (
    'ifDescr'		=> "1.3.6.1.2.1.2.2.1.2",
    'ifIndex'		=> "1.3.6.1.2.1.2.2.1.1",
    'ifAlias'		=> "1.3.6.1.2.1.31.1.1.1.18",
    'ifHCInOctets'	=> "1.3.6.1.2.1.31.1.1.1.6",
    'ifHCOutOctets'	=> "1.3.6.1.2.1.31.1.1.1.10",
    'ifInOctets'	=> "1.3.6.1.2.1.2.2.1.10",
    'ifOutOctets'	=> "1.3.6.1.2.1.2.2.1.16"
    );

my ($opt_ifType, $opt_host, $opt_port, $opt_help, $human_status, $exit_request, $human_error, $requestedInterface);
my $opt_interval=3;
my $opt_snmpver='2c';

Getopt::Long::Configure('bundling');
GetOptions
    ("h"   => \$opt_help, "help" => \$opt_help,
     "H=s" => \$opt_host, "hostname=s" => \$opt_host,
     "p=s" => \$opt_port, "port=s" => \$opt_port,
     "t=s" => \$opt_ifType, "iftype=s" => \$opt_ifType,
     "i=s" => \$opt_interval, "interval=s" => \$opt_interval,
     "v=s" => \$opt_snmpver,  "version=s" => \$opt_snmpver,
     "c=s" => \$opt_rcom, "community=s" => \$opt_rcom);


#validate input

if ($opt_help) {

    print "
SNMP Bandwidth Monitor 
Usage: $PROGNAME -H host -p port -c community -t interfaceType -i pollinterval -v snmpversion

Required:
-H, --hostname=HOST
   Name or IP address of the switch/router to change the vlan on

Optional:   
-h, --help 
   Print this message   
-p, --port=portid 
   SNMP ID of the port. Skips scanning the device.   
-c, --community=readcommunity
   SNMP read community. Defaults to public
-t, --ifType=[low|high]
   Type of interface. low is 32bit counter, high is 64bit counter. Defaults to trying 64 and falls back to 32.
-i, --interval=pollinterval
   Time in seconds between snmp polls. Defaults to 3 seconds.
-v, --version=snmpversion
   Manually specify the snmp version. Defaults to 2c.

";
    exit (0);
}

#ensure passed options are valid
unless ($opt_host) {print "Host name/address not specified\n"; exit (1)};
my $host = $1 if ($opt_host =~ /([-.A-Za-z0-9]+)/);
unless ($host) {print "Invalid host: $opt_host\n"; exit (1)};

unless (($opt_interval =~ /([0-9]+)/) && ($opt_interval > 0)){print "Invalid interval: $opt_interval. Must be an interger >= 1\n"; exit (1)};

if ($opt_ifType) {
    $opt_ifType = lc($opt_ifType);
    if (($opt_ifType ne 'low')&&($opt_ifType ne 'high')){
	print "Invalid type of interface: $opt_host . Options are low or high\n";
	exit (1)
    }
};

if ($opt_snmpver) {
    $opt_snmpver = lc($opt_snmpver);
    if (($opt_snmpver ne '1')&&($opt_snmpver ne '2c')){
	print "Invalid SNMP version: $opt_host . Only 1 and 2c are supported\n";
	exit (1)
    }
};

#start new snmp session
my $snmp = Net::SNMP->session(-hostname => $host,
                              -version  => $opt_snmpver,
			      -community => $opt_rcom);

#ensure we could set up the snmp session
checkSNMPStatus("SNMP Error: ",2);

#if user specifies interface skip scan and ensure interface exists
if ($opt_port) {
    unless ($opt_port =~ /([0-9]+)/){print "Invalid port: $opt_port. Must be an interger\n"; exit (1)};
    my $intTest = $snmp->get_request( -varbindlist => ["$oids{ifIndex}.$opt_port"]);
    checkSNMPStatus("SNMP Error: ",2);
    if ($intTest->{"$oids{ifIndex}.$opt_port"} eq 'noSuchInstance'){print "Requested interface $opt_port does not exist\n\n";exit 1;}
    $requestedInterface = $opt_port;

}else{
    #get a list of interfaces
    my $snmp_walk_ifindex = $snmp->get_entries( -columns => [$oids{ifIndex}]);

    checkSNMPStatus("Error getting interface list: ",2);

    #sort list of interfaces
    my @interfaceIds = sort {$a <=> $b} values $snmp_walk_ifindex;

    #get interface descr and aliases
    my $snmp_walk_ifDescr = $snmp->get_entries( -columns =>  [$oids{ifDescr}]);
    checkSNMPStatus("Error getting interface descriptions: ",2);
    my $snmp_walk_ifAlias = $snmp->get_entries( -columns =>  [$oids{ifAlias}]);
    if ($snmp->error()){
	#if device does not report aliases, populate the hash
	print "NOTE: Device does not report interface aliases\n";
	foreach (@interfaceIds){
	    $snmp_walk_ifAlias->{"$oids{ifAlias}.$_"} = "";
	}
    }

    print "\nAvailable interfaces:\n";
    my $interfaceTable = Text::TabularDisplay->new("SNMP ID", "INTERFACE", "ALIAS");

    foreach (@interfaceIds){
	$interfaceTable->add(["$_", "$snmp_walk_ifDescr->{\"$oids{ifDescr}.$_\"}", "$snmp_walk_ifAlias->{\"$oids{ifAlias}.$_\"}"]);
    }
    undef @interfaceIds;  # no longer need this, so undefine it

    print $interfaceTable->render;
    $interfaceTable->reset; #clean up the table

    print "\nWhich interface do you want to monitor (SNMP ID)? ";
    $requestedInterface = <>;
    chomp($requestedInterface);

    my $validInput = 0;

    while ($validInput == 0) {
	#check if input is valid
	if (exists $snmp_walk_ifindex->{"$oids{ifIndex}.$requestedInterface"}){
	    $validInput=1;
	}else{
	    print "\nInterface does not exist. Which interface do you want to monitor (SNMP ID)? ";
	    $requestedInterface = <>;
	    chomp($requestedInterface);
	}
    }
}

my $interfaceType = "";
if ($opt_ifType) {
    $interfaceType = $opt_ifType;
}else{
    #check to see if the device supports highspeed counters, if not fall back to lowspeed. 
    $snmp->get_request( -varbindlist => ["$oids{ifHCInOctets}.$requestedInterface"]);
    if ($snmp->error()){
	if ($opt_snmpver eq '1'){
	    print "NOTE: SNMP v1 does not support 64bit counters. Falling back to 32bit (counters may wrap)\n";
	}else{
	    print "NOTE: Device or interface does not support 64bit counters. Falling back to 32bit (counters may wrap)\n";
	}
	$interfaceType = 'low';
    }else{
	$interfaceType = 'high';
    }
}

#get init state
my ($inOct1, $outOct1);
if ("$interfaceType" eq "high"){
    $inOct1 = $snmp->get_request( -varbindlist => ["$oids{ifHCInOctets}.$requestedInterface"]);
    checkSNMPStatus("Error getting interface traffic counter: ",2);
    $inOct1 = $inOct1->{"$oids{ifHCInOctets}.$requestedInterface"};	

    $outOct1 = $snmp->get_request( -varbindlist => ["$oids{ifHCOutOctets}.$requestedInterface"]);
    checkSNMPStatus("Error getting interface traffic counter: ",2);
    $outOct1 = $outOct1->{"$oids{ifHCOutOctets}.$requestedInterface"};	

}else{
    $inOct1 = $snmp->get_request( -varbindlist => ["$oids{ifInOctets}.$requestedInterface"]);
    checkSNMPStatus("Error getting interface traffic counter: ",2);
    $inOct1 = $inOct1->{"$oids{ifInOctets}.$requestedInterface"};

    $outOct1 = $snmp->get_request( -varbindlist => ["$oids{ifOutOctets}.$requestedInterface"]);
    checkSNMPStatus("Error getting interface traffic counter: ",2);
    $outOct1 = $outOct1->{"$oids{ifOutOctets}.$requestedInterface"};
}

my $trafficData = Text::TabularDisplay->new("Time", "Octets In", "Octects Out", "KB/s In", "KB/s Out");

sleep $opt_interval;



while (1) {

    my ($inOct2, $outOct2, $inUsage, $outUsage);
    if ("$interfaceType" eq "high"){
	$inOct2 = $snmp->get_request( -varbindlist => ["$oids{ifHCInOctets}.$requestedInterface"]);
	checkSNMPStatus("Error getting interface traffic counter: ");
	$inOct2 = $inOct2->{"$oids{ifHCInOctets}.$requestedInterface"};	

	$outOct2 = $snmp->get_request( -varbindlist => ["$oids{ifHCOutOctets}.$requestedInterface"]);
	checkSNMPStatus("Error getting interface traffic counter: ");
	$outOct2 = $outOct2->{"$oids{ifHCOutOctets}.$requestedInterface"};	

    }else{
	$inOct2 = $snmp->get_request( -varbindlist => ["$oids{ifInOctets}.$requestedInterface"]);
	checkSNMPStatus("Error getting interface traffic counter: ");
	$inOct2 = $inOct2->{"$oids{ifInOctets}.$requestedInterface"};

	$outOct2 = $snmp->get_request( -varbindlist => ["$oids{ifOutOctets}.$requestedInterface"]);
	checkSNMPStatus("Error getting interface traffic counter: ");
	$outOct2 = $outOct2->{"$oids{ifOutOctets}.$requestedInterface"};
    }

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();

    #diff the polls, divided by the interval
    $inUsage = ($inOct2 - $inOct1) / $opt_interval;
    $outUsage = ($outOct2 - $outOct1) / $opt_interval;

    #convert from bits to kb
    $inUsage = $inUsage * 8 / 1024;
    $outUsage = $outUsage * 8 / 1024;

    $inUsage = sprintf("%.3f", $inUsage);
    $outUsage = sprintf("%.3f", $outUsage);

    $trafficData->add(["$hour:$min:$sec","$inOct2","$outOct2","$inUsage","$outUsage"]);
    print $clear_string;
    print $trafficData->render;
    print "\n";

    #store old values
    $inOct1= $inOct2;
    $outOct1 = $outOct2;

    sleep $opt_interval;

}

########################################################################################
#Functions!

#This function will do the error checking and reporting when related to SNMP
sub checkSNMPStatus {
    $human_error = $_[0];
    $exit_request = $_[1];
    
    my $snmp_error = $snmp->error;
    #check if there was an error, if so, print the requested message and the snmp error. I used the color red to get the user's attention.
    if ($snmp_error) {
	print "$human_error $snmp_error \n";
	#check to see if the error should cause the script to exit, if so, exit with the requested code
	if ($exit_request) {
	    print "\n";
	    exit $exit_request;
	}else{
	    return 1;
	}
    }
    return 0;
}


