# ict-install
Scripts for installing IOTA ICT on Debian or Redhat based linux.

Run on Debian based distros:
`sudo ./install-ict_debian.sh`

Run on Debian based distros:
`sudo ./install-ict_redhat.sh`


It will:
* Install required dependencies (Oracle Java8 JDK) 
* Add an user "ict"
* Download and compile the CfB´s ICT code in /home/ict/Ict
* Generate a run script
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



