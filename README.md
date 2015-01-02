#Bandwidth Monitor

###bandwidth_monitor.pl

By default the script will walk a device (specified via -H flag) with the community of
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
	+---------+----------------+---------------+
	| SNMP ID | INTERFACE      | ALIAS         |
	+---------+----------------+---------------+
	| 507     | vlan.3         |               |
	| 508     | ge-0/0/0       | wan           |
	| 509     | ge-0/0/0.0     |               |
	| 510     | ge-0/0/1       | wifi-router   |
	| 511     | fe-0/0/2       |               |
	| 512     | ge-0/0/1.0     |               |
	| 513     | fe-0/0/3       | backup-wan    |
	| 514     | fe-0/0/4       |               |
	| 515     | fe-0/0/2.0     |               |
	| 516     | fe-0/0/5       |               |
	| 517     | fe-0/0/3.0     |               |
	| 518     | fe-0/0/6       |               |
	| 519     | fe-0/0/7       |               |
	| 520     | fe-0/0/4.0     |               |
	| 521     | fe-0/0/5.0     |               |
	| 525     | ip-0/0/0       | he.net-tunnel |
	+---------+----------------+---------------+
	Which interface do you want to monitor (SNMP ID)?

Select an interface (example 508), hit return, and wait and you should see:

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
	
