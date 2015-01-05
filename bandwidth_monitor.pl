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
my $opt_rcom = 'public';

########################################################################################
my $PROGNAME     = "bandwidth_monitor.pl";
my $clear_string = `clear`;                  #used to clear the screen between polls

#Define oids we are going to use. This is done incase the mibs are not available.
my %oids = (
    'ifDescr'       => "1.3.6.1.2.1.2.2.1.2",
    'ifIndex'       => "1.3.6.1.2.1.2.2.1.1",
    'ifAlias'       => "1.3.6.1.2.1.31.1.1.1.18",
    'ifHCInOctets'  => "1.3.6.1.2.1.31.1.1.1.6",
    'ifHCOutOctets' => "1.3.6.1.2.1.31.1.1.1.10",
    'ifInOctets'    => "1.3.6.1.2.1.2.2.1.10",
    'ifOutOctets'   => "1.3.6.1.2.1.2.2.1.16"
);

my ( $opt_ifType, $opt_host, $opt_port, $opt_help, $human_status, $exit_request, $human_error, $requestedInterface );
my $opt_interval = 3;       #Default poll interval of 3 seconds
my $opt_snmpver  = '2c';    #Default to snmpv2c

Getopt::Long::Configure('bundling');
GetOptions(
    "h|help|?"      => \$opt_help,
    "H|hostname=s"  => \$opt_host,
    "p|port=s"      => \$opt_port,
    "t|iftype=s"    => \$opt_ifType,
    "i|interval=s"  => \$opt_interval,
    "v|version=s"   => \$opt_snmpver,
    "c|community=s" => \$opt_rcom
);

#Help message

if ($opt_help) {

    print "
SNMP Bandwidth Monitor 
Usage: $PROGNAME -H host -p port -c community -t interfaceType -i pollinterval -v snmpversion

Required:
-H, --hostname=HOST
   Name or IP address of the target host

Optional:
-h, --help 
   Print this message and exit.
-p, --port=portid
   SNMP ID of the port or interface. Skips scanning the device.
-c, --community=readcommunity
   SNMP read community. Defaults to public.
-t, --ifType=[low|high]
   Type of interface. low is 32bit counter, high is 64bit counter. Defaults to trying 64 and falls back to 32.
-i, --interval=pollinterval
   Time in seconds between snmp polls. Defaults to 3 seconds.
-v, --version=snmpversion
   Manually specify the snmp version. Defaults to 2c.

";
    exit(0);
}

#Ensure valid hostname
unless ($opt_host) { print "Host name/address not specified\n"; exit(1) }
my $host = $1 if ( $opt_host =~ /([-.A-Za-z0-9]+)/ );
unless ($host) { print "Invalid host: $opt_host\n"; exit(1) }

#Ensure interval is an interger greater then 1
unless ( ( $opt_interval =~ /([0-9]+)/ ) && ( $opt_interval > 0 ) ) { print "Invalid interval: $opt_interval. Must be an interger >= 1\n"; exit(1) }

#Ensure iftype is high or low and lc it
if ($opt_ifType) {
    $opt_ifType = lc($opt_ifType);
    if ( ( $opt_ifType ne 'low' ) && ( $opt_ifType ne 'high' ) ) {
        print "Invalid type of interface: $opt_host . Options are low or high\n";
        exit(1);
    }
}

#Ensure snmpversion is either 2c or 1.
if ($opt_snmpver) {
    $opt_snmpver = lc($opt_snmpver);
    if ( ( $opt_snmpver ne '1' ) && ( $opt_snmpver ne '2c' ) ) {
        print "Invalid SNMP version: $opt_host . Only 1 and 2c are supported\n";
        exit(1);
    }
}

#start new snmp session
my $snmp = Net::SNMP->session(
    -hostname  => $host,
    -version   => $opt_snmpver,
    -community => $opt_rcom
);

#Ensure we could set up the snmp session, this can fail for many reasons
checkSNMPStatus( "SNMP Error: ", 2 );

#If user specifies interface skip walking the device and ensure interface exists
if ($opt_port) {
    unless ( $opt_port =~ /([0-9]+)/ ) { print "Invalid port: $opt_port. Must be an interger\n"; exit(1) }
    my $intTest = $snmp->get_request( -varbindlist => ["$oids{ifIndex}.$opt_port"] );
    checkSNMPStatus( "SNMP Error: ", 2 );
    if ( $intTest->{"$oids{ifIndex}.$opt_port"} eq 'noSuchInstance' ) { print "Requested interface $opt_port does not exist\n\n"; exit 1; }
    $requestedInterface = $opt_port;

}

#User did not specify the interface
else {
    #Get a list of interfaces by walking ifindex
    my $snmp_walk_ifindex = $snmp->get_entries( -columns => [ $oids{ifIndex} ] );

    checkSNMPStatus( "Error getting interface list: ", 2 );

    #Sort list of interfaces for later
    my @interfaceIds = sort { $a <=> $b } values %$snmp_walk_ifindex;

    #Get interface descr and aliases
    my $snmp_walk_ifDescr = $snmp->get_entries( -columns => [ $oids{ifDescr} ] );
    checkSNMPStatus( "Error getting interface descriptions: ", 2 );
    my $snmp_walk_ifAlias = $snmp->get_entries( -columns => [ $oids{ifAlias} ] );
    if ( $snmp->error() ) {

        #If device does not report aliases, populate the hash to prevent errors
        print "NOTE: Device does not report interface aliases\n";
        foreach (@interfaceIds) {
            $snmp_walk_ifAlias->{"$oids{ifAlias}.$_"} = "";
        }
    }

    #Start generating the table
    print "\nAvailable interfaces:\n";
    my $interfaceTable = Text::TabularDisplay->new( "SNMP ID", "INTERFACE", "ALIAS" );

    #Go through each interface in order and add a row to the table with its data
    foreach (@interfaceIds) {
        $interfaceTable->add( [ "$_", "$snmp_walk_ifDescr->{\"$oids{ifDescr}.$_\"}", "$snmp_walk_ifAlias->{\"$oids{ifAlias}.$_\"}" ] );
    }
    undef @interfaceIds;    #No longer need this, so undefine it

    print $interfaceTable->render;
    $interfaceTable->reset;    #Clean up the table

    print "\nWhich interface do you want to monitor (SNMP ID)? ";
    $requestedInterface = <>;
    chomp($requestedInterface);

    my $validInput = 0;

    #Validate user input and keep promting till something valid is entered.
    while ( $validInput == 0 ) {

        #See if interface is in the ifindex
        if ( exists $snmp_walk_ifindex->{"$oids{ifIndex}.$requestedInterface"} ) {
            $validInput = 1;
        }
        else {
            print "\nInterface does not exist. Which interface do you want to monitor (SNMP ID)? ";
            $requestedInterface = <>;
            chomp($requestedInterface);
        }
    }
}

my $interfaceType = "";

#If the interface type was specified then skip checking which the device supports
if ($opt_ifType) {

    #Show error and exit if trying to use 64bit counters with snmp v1
    if ( ( $opt_snmpver eq '1' ) && ( $opt_ifType eq 'high' ) ) {
        print "ERROR: You cannot use 64bit counters with SNMPv1!\n\n";
        exit 2;
    }

    $interfaceType = $opt_ifType;

}
else {
    #Check to see if the device supports highspeed counters, if not fall back to lowspeed.
    $snmp->get_request( -varbindlist => ["$oids{ifHCInOctets}.$requestedInterface"] );
    if ( $snmp->error() ) {
        if ( $opt_snmpver eq '1' ) {
            print "NOTE: SNMP v1 does not support 64bit counters. Falling back to 32bit (counters may wrap)\n";
        }
        else {
            print "NOTE: Device or interface does not support 64bit counters. Falling back to 32bit (counters may wrap)\n";
        }
        $interfaceType = 'low';
    }
    else {
        $interfaceType = 'high';
    }
}

#Give notice to use to wait for interval time
print "\nPlease wait for $opt_interval seconds... Press ctrl+c at any time to exit $PROGNAME.\n";

#Init traffic data
my ( $inOct1, $outOct1 );
if ( "$interfaceType" eq "high" ) {
    $inOct1 = $snmp->get_request( -varbindlist => ["$oids{ifHCInOctets}.$requestedInterface"] );
    checkSNMPStatus( "Error getting interface traffic counter: ", 2 );
    $inOct1 = $inOct1->{"$oids{ifHCInOctets}.$requestedInterface"};

    $outOct1 = $snmp->get_request( -varbindlist => ["$oids{ifHCOutOctets}.$requestedInterface"] );
    checkSNMPStatus( "Error getting interface traffic counter: ", 2 );
    $outOct1 = $outOct1->{"$oids{ifHCOutOctets}.$requestedInterface"};

}
else {
    $inOct1 = $snmp->get_request( -varbindlist => ["$oids{ifInOctets}.$requestedInterface"] );
    checkSNMPStatus( "Error getting interface traffic counter: ", 2 );
    $inOct1 = $inOct1->{"$oids{ifInOctets}.$requestedInterface"};

    $outOct1 = $snmp->get_request( -varbindlist => ["$oids{ifOutOctets}.$requestedInterface"] );
    checkSNMPStatus( "Error getting interface traffic counter: ", 2 );
    $outOct1 = $outOct1->{"$oids{ifOutOctets}.$requestedInterface"};
}

#Make a new table for the traffic data
my $trafficData = Text::TabularDisplay->new( "Time", "Octets In", "Octects Out", "KB/s In", "KB/s Out" );

#Sleep for the requested interval to get the proper diff
sleep $opt_interval;

#Keep polling data and printing new table till user exits
while (1) {

    my ( $inOct2, $outOct2, $inUsage, $outUsage );

    #Get data depending on interface type
    if ( "$interfaceType" eq "high" ) {
        $inOct2 = $snmp->get_request( -varbindlist => ["$oids{ifHCInOctets}.$requestedInterface"] );
        checkSNMPStatus("Error getting interface traffic counter: ");
        $inOct2 = $inOct2->{"$oids{ifHCInOctets}.$requestedInterface"};

        $outOct2 = $snmp->get_request( -varbindlist => ["$oids{ifHCOutOctets}.$requestedInterface"] );
        checkSNMPStatus("Error getting interface traffic counter: ");
        $outOct2 = $outOct2->{"$oids{ifHCOutOctets}.$requestedInterface"};

    }
    else {
        $inOct2 = $snmp->get_request( -varbindlist => ["$oids{ifInOctets}.$requestedInterface"] );
        checkSNMPStatus("Error getting interface traffic counter: ");
        $inOct2 = $inOct2->{"$oids{ifInOctets}.$requestedInterface"};

        $outOct2 = $snmp->get_request( -varbindlist => ["$oids{ifOutOctets}.$requestedInterface"] );
        checkSNMPStatus("Error getting interface traffic counter: ");
        $outOct2 = $outOct2->{"$oids{ifOutOctets}.$requestedInterface"};
    }

    #Get time data for timestamp
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime();

    #Diff the polls, divided by the interval
    $inUsage  = ( $inOct2 - $inOct1 ) / $opt_interval;
    $outUsage = ( $outOct2 - $outOct1 ) / $opt_interval;

    #Donvert from bits to kb
    $inUsage  = $inUsage * 8 / 1024;
    $outUsage = $outUsage * 8 / 1024;

    #Limit float percision
    $inUsage  = sprintf( "%.3f", $inUsage );
    $outUsage = sprintf( "%.3f", $outUsage );

    #Add new row to table
    $trafficData->add( [ "$hour:$min:$sec", "$inOct2", "$outOct2", "$inUsage", "$outUsage" ] );

    #Clear the screen and reprint the table
    print $clear_string;
    print $trafficData->render;
    print "\n";

    #Dtore old values
    $inOct1  = $inOct2;
    $outOct1 = $outOct2;

    sleep $opt_interval;

}

########################################################################################
#Functions!

#This function will do the error checking and reporting when related to SNMP
sub checkSNMPStatus {
    $human_error  = $_[0];
    $exit_request = $_[1];

    my $snmp_error = $snmp->error;

    #check if there was an error, if so, print the requested message and the snmp error. I used the color red to get the user's attention.
    if ($snmp_error) {
        print "$human_error $snmp_error \n";

        #check to see if the error should cause the script to exit, if so, exit with the requested code
        if ($exit_request) {
            print "\n";
            exit $exit_request;
        }
        else {
            return 1;
        }
    }
    return 0;
}

