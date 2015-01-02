#Bandwidth Monitor

###bandwidth_monitor.pl

By default the script will walk the device with the community of
`public` and generate a table of interfaces for you to pick. Then it
will poll the traffic stats (64bit by default, falls back to 32bit).

Run with -h for more options

Requires:
* Net::SNMP
* Text::TabularDisplay


### Example usage

Example of running the script:

	$ ./bandwidth_monitor.pl -H tardis -c myReadCommunity

	Available interfaces:
	+---------+-----------+-------+
	| SNMP ID | INTERFACE | ALIAS |
	+---------+-----------+-------+
	| 1       | lo        |       |
	| 2       | enp7s0    |       |
	| 3       | enp8s0    |       |
	| 4       | br0       |       |
	| 5       | vnet0     |       |
	+---------+-----------+-------+
	Which interface do you want to monitor (SNMP ID)?

Select an interface and wait and you should see:

	+----------+------------+-------------+------------+------------+
	| Time     | Octets In  | Octects Out | KB/s In    | KB/s Out   |
	+----------+------------+-------------+------------+------------+
	| 18:29:18 | 2578355749 | 2512183235  | 40838.951  | 3728.711   |
	| 18:29:21 | 2579527226 | 2512510463  | 3050.721   | 852.156    |
	| 18:29:24 | 2579917760 | 2514998893  | 1017.016   | 6480.286   |
	| 18:29:27 | 2683313664 | 2516496963  | 269260.167 | 3901.224   |
	| 18:29:30 | 2769125980 | 2519428352  | 223469.573 | 7633.826   |
	| 18:29:33 | 2771600806 | 2519845916  | 6444.859   | 1087.406   |
	| 18:29:36 | 2869527446 | 2521448643  | 255017.292 | 4173.768   |
	| 18:29:39 | 2874233092 | 2523214797  | 12254.286  | 4599.359   |
	+----------+------------+-------------+------------+------------+
	
