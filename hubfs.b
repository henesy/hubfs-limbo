implement Hubfs;

include "sys.m";
	sys: Sys;
	print: import sys;

include "draw.m";

include "arg.m";
	arg: Arg;

include "styx.m";
	styx: Styx;
	Tmsg, Rmsg: import styx;

include "styxservers.m";
	styxservers: Styxservers;
	Styxserver, Navigator, Navop, readbytes, readstr: import styxservers;
	nametree: Nametree;
	Tree: import nametree;

# input/output multiplexing and buferring
# often used in combination with hubshell client and hub wrapper script

# Flags track the state of queued 9p requests and ketchup/wait in paranoid mode
DOWN, UP, WAIT, DONE: con iota;

# Buffer sizes
MAGIC: con 77777;
MAXQ: con 777;
SMBUF: con 777;
MAXHUBS: con 77;

# Errors
Ebad: con string "something bad happened";
Enomem: con string "no memory";

Qroot: con big 0;

Hub: adt {
	name: string;				# name 
	bucket: array of byte;		# pointer to data buffer 
	# char *inbuckp;			# location to store next message 
	# int buckfull;				# amount of data stored in bucket 
	# char *buckwrap;			# exact limit of written data before pointer reset 
	# Req *qreads[MAXQ];		# pointers to queued read Reqs 
	rstatus: array of int;			# status of read requests [MAXQ]
	qrnum: int;				# index of read Reqs waiting to be filled 
	qrans: int;					# number of read Reqs answered 
	# Req *qwrites[MAXQ];		# Similar for write Reqs 
	wstatus: array of int;			# [MAXQ]
	qwnum: int;
	qwans: int;
	ketchup: int;				# lag of readers vs. writers in paranoid mode 
	tomatoflag: int;				# readers use tomatoflag to tell writers to wait 
	# QLock wrlk;				# writer lock during fear 
	# QLock replk;				# reply lock during fear 
	killme: int;				# forked processes in paranoid mode need to exit 
	# Limiter *lp;				# Pointer to limiter struct for this hub 
	bp: big;					# Bytes per second that can be written 
	st: big;					# minimum separation time between messages in ns 
	rt: big;					# Interval in seconds for resetting limit timer 
};

Msgq: adt {
	myfid: big;	# Msgq is associated with client fids
	# char *nxt	# Location of this client in the buffer 
	bufuse: int;	# how much of the buffer has been used 
};

# Replaces Hublist{} type
hublist: list of ref Hub;

srvname: string;			# Name of this hubfs service 
numhubs: int;				# Total number of hubs in existence 
paranoia: int;				# Paranoid mode maintains loose reader/writer sync 
freeze: int;				# In frozen mode the hubs operate simply as a ramfs 
trunc: int;					# In trunc mode only new data is sent, not buffered 
allowzap: int;				# Determine whether a buffer can be emptied forcibly 
endoffile: int;				# Send zero length end of file read to all clients 
applylimits: int;				# Whether time/rate limits are applied 
bytespersecond: big;		# Bytes per second allowed by rate limiting 
separationinterval: big;		# Minimum time between writes in nanoseconds 
resettime: big;				# Number of seconds between writes ratelimit reset 
maxmsglen: big;			# Maximum message length accepted 
bucksize: big;				# Size of data bucket per hub 

# Styx/9p stuffs
srv: ref Styxserver;			# Srv structure
tchan: chan of ref Tmsg;		# Channel for talking to styx server

tree: ref Tree;
treeop: chan of ref Navop;

Hubfs: module {
	init: fn(nil: ref Draw->Context, nil: list of string);
};


init(nil: ref Draw->Context, argv: list of string) {
	sys = load Sys Sys->PATH;
	styx = load Styx Styx->PATH;
	arg = load Arg Arg->PATH;
	arg->init(argv);

	addr := "";
	mtpt := "";
	# Qid q;
	srvname = "";
	paranoia = DOWN;
	freeze = DOWN;
	trunc = DOWN;
	allowzap = DOWN;
	endoffile = DOWN;
	applylimits = DOWN;
	numhubs = 0;
	bytespersecond = big 1073741824;
	separationinterval = big 1;
	resettime =  big 60;
	maxmsglen = big 666666;
	bucksize = big 777777;

	arg->setusage(arg->progname() + " [-D] [-t] [-q bucketsize] [-b bytespersec] [-i nsbetweenmsgs]" +
		" [-r timerreset] [-l maxmsglen] [-s srvname] [-m mtpt]");

	while((c := arg->opt()) != 0)
		case c {
		'D' =>
			;;	# Not sure how to set chatty9p in styxservers(2)
		'q' =>
			bucksize = big arg->earg();
			
		'b' =>
			bytespersecond = big arg->earg();
			applylimits = UP;
			
		'i' =>
			separationinterval = big arg->earg();
			applylimits = UP;
			
		'r' =>
			resettime = big arg->earg();
			applylimits = UP;
			
		'l' =>
			maxmsglen = big arg->earg();
			
		'a' =>
			addr = arg->earg();
			
		's' =>
			srvname = arg->earg();
			
		'm' =>
			mtpt = arg->earg();
			
		't' =>
			trunc = UP;
			
		'z' =>
			allowzap = UP;
			
		* =>
			arg->usage();
		}

	argv = arg->argv();

	if(len argv > 0)
		arg->usage();

	if(addr == nil && srvname == nil && mtpt == nil)	
		raise "must specify -a, -s, or -m option";

	# Set up styx
	styx->init();
	styxservers = load Styxservers Styxservers->PATH;
	styxservers->init(styx);

	nametree = load Nametree Nametree->PATH;
	nametree->init();

	(tree, treeop) = nametree->start();
	tree.create(Qroot, dir(".", 8r555|Sys->DMDIR, Qroot));

	(tchan, srv) = Styxserver.new(sys->fildes(0), Navigator.new(treeop), Qroot);

	# Start listener
	spawn server(tchan, srv);

	exit;
}

# 9p listening server
server(tchan: chan of ref Tmsg, srv: ref Styxserver) {
	# TODO
}

# Create a directory
dir(name: string, perm: int, qid: big): Sys->Dir {
	d := sys->zerodir;
	d.name = name;
	d.uid = "none";		# TODO
	d.gid = "none";
	d.qid.path = qid;
	if (perm & Sys->DMDIR)
		d.qid.qtype = Sys->QTDIR;
	else
		d.qid.qtype = Sys->QTFILE;
	d.mode = perm;
	return d;
}
