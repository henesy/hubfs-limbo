# hubfs-limbo
<WIP> rewrite of Mycroftiv's hubfs in Limbo for Inferno https://bitbucket.org/mycroftiv/hubfs

Provides GNU screen-like functionality via a 9p fs of io Hubs.
Use the hub wrapper script to start the hubfs and hubshell.

STARTING AND CONNECTING WITH 'HUB' WRAPPER SCRIPT

	hub aug5 #starts and connects to a new hubfs and posts /srv/aug5
	hub aug5 #connects a new client to the rc shell started by the previous command
	hub aug5 rctwo #starts and connects to new rc named rctwo within the aug5 hubfs
	hub #starts a hubfs named hubfs with an rc named io
	hub #connects to the default hubfs io

MAKING NEW SHELLS AND MOVING IN HUBSHELL:

	-all commands begin with '%' as first character-
	%detach  #disconnect from attached shell
	%remote NAME #start a new shell on remote machine
	%local NAME #start a new shell on local machine shared to hubfs server
	%attach NAME #move to an existing hubfs shell
	%err TIME, %in TIME, %out TIME #time in ms for delay loop on file access
	%status #basic hubfs connection info
	%list #lc of connected hubfs hubs

CONTROLLING HUBFS ITSELF VIA CTL FILE:

	-reading from ctl file returns status-
	echo freeze >/n/hubsrv/ctl #freeze Hubs as static files for viewing and editing
	echo melt >/n/hubsrv/ctl #resume normal flow of data
	echo fear >/n/hubsrv/ctl #activate paranoid mode and fswrites wait for fsreads to output data
	echo calm >/n/hubsrv/ctl #resume standard non-paranoid data transmission mode
	echo quit >/n/hubsrv/ctl #bring everything to a crashing halt and kill the fs

NOTES:

Each rc shell makes use of 3 Hubs, one for each file descriptor.

A Hub file provides both input and output.

You can create additional freeform pipelines by touching files to create Hubs.

SCRIPTS FOR USE FROM P9P/UNIX:

I use 9pfuse in combination with a one-connection listener from plan9
and two tiny scripts to let me access plan 9 hubfs shells from linux
and share linux shells back to plan9.  Here is an example sequence:

plan9:

	hub -b linhub
	mount -c /srv/linhub /n/linhub
	touch /n/linhub/lin0
	touch /n/linhub/lin1
	touch /n/linhub/lin2
	aux/listen1 -tv tcp!*!19999 /bin/exportfs -r /n/linhub 
	# non-authed listen1 will be open for a few seconds, monitor -v output

# References

- https://github.com/caerwynj/inferno-lab/blob/master/4/signalfs.b
