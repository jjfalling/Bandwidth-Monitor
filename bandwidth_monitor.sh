#!/usr/bin/env bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

#****************************************************************************
#*   Usage	                                                            *
#*   Show the bandwidth of a given port using snmp                          *
#*                                                                          *
#*   Copyright (C) 2013 by Jeremy Falling except where noted.               *
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


# CHANGELOG
#
# V1.0 
#		*first attempt
# V1.1 
#		*fixed the math so this spits out kbits not kbytes. also changed 
#		 runtime from 15 to 60 seconds

#############################################################################


echo ""
echo "This program gets the usage from a devices port using SNMP."
echo "Octets and usage are displayed for 60 seconds before program asks to continue."
echo ""
echo ""

#ask user for a few things
echo -n "Enter IP address or FQDN: "
read -e HOST

echo -n "Enter snmp value interface:  "
read -e INTERFACE

echo -n "Do you want to use the default snmp comunity?  [yes/no]"
read -e DEFAULTCOMUNITY

while [ concount != 1 ]
do
	if [[ $DEFAULTCOMUNITY == "yes" ]]
	then

		snmpcomunity="public"  #The default snmp comunity is set to the standard public. You may want to change this.
		concount="1"
		break

	elif [[ $DEFAULTCOMUNITY == "no" ]]
	then

		echo ""
		echo ""
		echo -n "Enter snmp comunity: "
		read -e snmpcomunity
		break

	else

		echo "Please type yes or no"
		read -e DEFAULTCOMUNITY

	fi
done

#confirm selections
echo "You selected: "
echo ""
echo "Host: " $HOST
echo "Interface: " $INTERFACE
echo "Comunity: " $snmpcomunity

#start polling and displaying data for 60 seconds

mainexit=0

while [ mainexit != "1" ]
do

	#get initial value
	inoct1=`snmpget -v1 -c "$snmpcomunity" "$HOST" interfaces.ifTable.ifEntry.ifInOctets."$INTERFACE" |sed 's/IF-MIB::ifInOctets.* = Counter32: //'`
	outoct1=`snmpget -v1 -c "$snmpcomunity" "$HOST" interfaces.ifTable.ifEntry.ifOutOctets."$INTERFACE" |sed 's/IF-MIB::ifOutOctets.* = Counter32: //'`

	sleep 1

	echo ""
	echo ""
	echo "In Octets  |Out Octets  |Kb/s in  |Kb/s out"
	echo "-------------------------------------------------------------------"
	i="0"

	while [ $i -lt 60 ]
	do
    
		#get value
		inoct2=`snmpget -v1 -c "$snmpcomunity" "$HOST" interfaces.ifTable.ifEntry.ifInOctets."$INTERFACE" |sed 's/IF-MIB::ifInOctets.* = Counter32: //'`
		outoct2=`snmpget -v1 -c "$snmpcomunity" "$HOST" interfaces.ifTable.ifEntry.ifOutOctets."$INTERFACE" |sed 's/IF-MIB::ifOutOctets.* = Counter32: //'`
    
    
		#initial minus current to use for bandwidth calc
		let inoct_diff=$inoct2-$inoct1
		let outoct_diff=$outoct2-$outoct1
    
		#turn octets into bits then turn into kbits
		let inusage=$inoct_diff*8/1024
		let outusage=$outoct_diff*8/1024
    
		echo "$inoct2  |$outoct2  |$inusage  |$outusage" 
    
		inoct1=$inoct2
		outoct1=$outoct2
		sleep 1
		i=$[$i+1]
    
	done
	
  
	echo ""
	echo ""
	echo "Do you want more data?  [yes/no]"
	read -e MAINCONTINUE
	

	while [ concount2 != 1 ]
	do

		if [[ $MAINCONTINUE == "yes" ]]
		then

			concount2=1
			break

	elif [[ $MAINCONTINUE == "no" ]]
	then

		echo ""
		echo ""
		echo "User wishes to exit..."
		concount2="1"
		mainexit="1"
		exit 1

	else

		echo "Please type yes or no"
		read -e MAINCONTINUE

	fi
	done

done

#end of program 
exit 0
