# ict-install
Scripts for installing IOTA ICT (current omegan version) on Debian or Redhat based linux.


Run on Debian based distros:

`sudo ./install-ict_debian.sh BUILD`
to build and run ict from the current src at github.

`sudo ./install-ict_debian.sh RELEASE`
to download and run the latest binary release from github.


Run on Redhat based distros:

`sudo ./install-ict_rehat.sh BUILD`
to build and run ict from the current src at github.

`sudo ./install-ict_redhat.sh RELEASE`
to download and run the latest binary release from github.


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

### UnknownHostException

This error is usually due to an invalid entry in the `ict.properties` file.
e.g. neighborCHost = ?.?.?.?
is not a valid hostname.

Make sure you only use valid hostnames or ip addresses.

Sometimes this error is caused by trailing white spaces in the hostname.

Example of a valid file:

```
host = 0.0.0.0
port = 14265
neighborAHost = 127.0.0.1
neighborAPort = 14265
neighborBHost = 127.0.0.2
neighborBPort = 14265
neighborCHost = 127.0.0.3
neighborCPort = 14265
```

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

If you run ICT as a systemd service, run
`sudo crontab -e`
and add
`2 22 * * * systemctl restart ict`
to your crontab to restart ICT at 2:22am every night.

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



