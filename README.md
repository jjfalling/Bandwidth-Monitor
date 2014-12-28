###bandwidth_monitor.pl

By default the script will walk the device with the community of
`public` and generate a table of interfaces for you to pick. Then it
will poll the traffic stats (64bit by default, falls back to 32bit).

Run with -h for more options

Also requires:
Net::SNMP
Text::TabularDisplay
