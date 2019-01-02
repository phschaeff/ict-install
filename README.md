# ict-install
Scripts for installing IOTA ICT (current omegan version) on linux.


## BUILD install
Run:

`sudo ./install-ict.sh BUILD "<name> (ict-<number>)"`
to build and run ict from the current src at github (including prereleases and snapshots).
This also builds and runs Report.ixi and builds and installs (but does not run) chat.ixi.

In order to start chat.ixi run: 
`sudo systemctl start ict_chat-ixi`
Username and password are configured in `/home/ict/config/chat.ixi.cfg`.

The option "Nick (ict-0)" is needed by Report.ixi. If not provided the install script will ask for it at a later point.
The naming convention is: `"<name> (ict-<number>)"`
  where name is your nickname on discord
  and number is the number of your ict. 


## RELEASE install
Run:
`sudo ./install-ict.sh RELEASE nodename`
to download and run the latest binary release from github.

nodename can be left blank.

It will:
* Install required dependencies (Oracle Java8 JDK) 
* Add an user "ict"
* Download and compile the omegas ICT code in /home/ict/omega-ict
* Generate a run script
* Import settings from old `ict.properties` (has to be located in `/home/ict/config/ict.properties`)
* Generate a systemd service
* Generate a cronjob restarting ICT every night
* Start the ICT service


Tested on:
* Ubuntu 18.04
* Ubuntu 16.04 LTS
* Kali (rolling)
* Debian 9
* Raspbian 9
* OpenHabianPi
* Amazon Linux release 2 (Karoo)

## Troubleshooting Guide

Some common errors encountered when starting ict.

### Error starting Report.ixi
If the ict_report-ixi-service starts with the following error:

`INFO  [main/ReportIxi]   Can't connect to Ict 'ict'. Make sure that the Ict Client is running. Check 'ictName' in report.ixi.cfg and 'ixi_enabled=true' in ict.cfg.`

the solution may be simply restarting the services, as in (as root):

`systemctl stop ict_report-ixi.service ; systemctl restart ict ; sleep 1; systemctl start ict_report-ixi.service ;  journalctl -f _UID=$(id -u ict)`


### UnknownHostException

This error is usually due to an invalid entry in the `ict.properties` file.
e.g. neighborCHost = ?.?.?.?
is not a valid hostname.

Make sure you only use valid hostnames or ip addresses.

Sometimes this error is caused by trailing white spaces in the hostname.

### BindException

Address already in use (Bind failed)
This error occurs when ICT is started while another process already is using the `port` specified in the `ict.properties` file.
Usually this may be another instance of ICT or IRI.

Check for processes running on port 14265 by running:
`sudo netstat -ntalpu | grep 14265`

### OutOfMemoryError

This error may occure after ICT has been running for some time.
While ICT is running the internal representation of the ICT tangle keeps growing.
(Local snapshots have not been implemented, yet.)
You can avoid this error by restarting ICT on a regular basis.


### Multiple IP addresses

If your ICT node has multiple IP addresses, e.g.
- multiple network interface
- IPv4 and IPv6 dual stack
- multiple stateless IPv6 addresses assigned
the node may use a different IP address for sending transactions than for receiving transactions.

Your neighbours won´t recognize your transactions then, since they seem to be coming from an unknown IP address.
Make sure your outgoing traffic is using the same IP address your neighbours have configured in their `ict.properties` file.

You can check your traffic by running
`sudo tcpdump -vv -n -i any port 14265`



