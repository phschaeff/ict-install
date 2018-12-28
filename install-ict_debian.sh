#/bin/sh

ICTHOME="/home/ict"
ICTDIR="omega-ict"
GITREPO="iotaledger/ict"
HOST="0.0.0.0"
PORT="14265"
NEIGHBORS="127.0.0.1:14265,127.0.0.2:14265,127.0.0.3:14265"

if [ -z "$1" ] || [ "$1" != "BUILD" -a "$1" != "RELEASE" ] ; then
	echo 'Please choose between BUILD or RELEASE:'
    echo './$0 BUILD|RELEASE ["NODENAME (ict-0)"]'
    exit
fi

apt-get update
apt-get upgrade -y
apt-get install curl -y --install-recommends

useradd -d ${ICTHOME} -m -s /bin/bash ict
mkdir -p ${ICTHOME}/${ICTDIR}
cd ${ICTHOME}/${ICTDIR}

if [ "$1" = "BUILD" ]; then
	apt-get install git gnupg dirmngr gradle -y --install-recommends
	grep "^deb .*webupd8team" /etc/apt/sources.list || echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list
	grep "^deb-src .*webupd8team" /etc/apt/sources.list || echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" >> /etc/apt/sources.list
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C2518248EEA14886
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886
	apt-get update
	apt-get upgrade -y
	echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
	echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
	apt-get install oracle-java8-installer oracle-java8-set-default -y --allow-unauthenticated

	if [ -d ${ICTHOME}/${ICTDIR}/ict/.git ]; then
		cd ${ICTHOME}/${ICTDIR}/ict
		git pull
	else
		cd ${ICTHOME}/${ICTDIR}
		git clone https://github.com/${GITREPO}
	fi
	cd ${ICTHOME}/${ICTDIR}/ict
	rm -f *.jar
	gradle fatJar || exit "BUILD did not work. Try ./$0 RELEASE [\"NODENAME (ict-0)\"]"
	VERSION=`ls *.jar | sed -e 's/ict-\(.*\)\.jar/\1/'`
fi

if [ "$1" = "RELEASE" ]; then
	VERSION=`curl --silent "https://api.github.com/repos/${GITREPO}/releases" | grep '"tag_name":' |head -1 | sed -E 's/.*"([^"]+)".*/\1/'`
	if [ ! -f ict/ict-${VERSION}.jar ]; then
			mkdir ict
			cd ict
			rm -f *.jar
			wget https://github.com/iotaledger/ict/releases/download/${VERSION}/ict-${VERSION}.jar
	fi
fi


cat <<EOF > ${ICTHOME}/run-ict.sh
#!/bin/sh
cd ${ICTHOME}/${ICTDIR}
#start ixi here
java -jar ${ICTHOME}/${ICTDIR}/ict/ict-${VERSION}.jar -c ${ICTHOME}/config/ict.cfg
EOF

chmod a+x ${ICTHOME}/run-ict.sh


mkdir -p ${ICTHOME}/config
cd ${ICTHOME}/${ICTDIR}
rm -f ict.cfg
java -jar /home/ict/omega-ict/ict/ict-0.3-SNAPSHOT.jar &
last_pid=$!
sleep 3
kill -KILL $last_pid

if [ ! -f ${ICTHOME}/config/ict.cfg ]; then
	if [ -f ${ICTHOME}/config/ict.properties ]; then
		host=`sed -ne 's/^host\s*=\s*//gp' ${ICTHOME}/config/ict.properties`
		port=`sed -ne 's/^port\s*=\s*//gp' ${ICTHOME}/config/ict.properties`
		neighbors=`sed -ne 's/^neighbor\(A\|B\|C\)\(Host\|Port\)\s*=\s*//gp' ${ICTHOME}/config/ict.properties | sed ':a;N;$!ba;s/\n/:/g;s/:\([^:]*\):/:\1,/g'`
		sed -i 's/^host=.*$/host=$host/;s/^port=.*$/port=$port/;s/^neighbors=.*$/neighbors=$neighbors/' ict.cfg
	fi
else
	IFS="="
	cat ${ICTHOME}/config/ict.cfg | while read -r varname value ; do
		echo "Setting config $varname to ${value}"
		sed -i "s/^$varname=.*$/$varname=$value/" ict.cfg
	done
fi

if [ ! -z "$2" ] ; then
	echo "Setting name of the node to $2"
	sed -i "s/^name=.*$/name=$2/" ict.cfg
fi

cp -f ${ICTHOME}/config/ict.cfg ${ICTHOME}/config/ict.cfg.last
cp -f ict.cfg ${ICTHOME}/config/ict.cfg
chown -R ict ${ICTHOME}/config ${ICTHOME}/${ICTDIR}

cat <<EOF > /lib/systemd/system/ict.service
[Unit]
Description=IOTA ICT
After=network.target
[Service]
ExecStart=/bin/bash -u ${ICTHOME}/run-ict.sh
WorkingDirectory=${ICTHOME}/${ICTDIR}
StandardOutput=inherit
StandardError=inherit
Restart=always
User=ict
[Install]
WantedBy=multi-user.target
EOF

grep "systemctl restart ict" /var/spool/cron/crontabs/root && sed -i 's/^.*systemctl restart ict.*$//' /var/spool/cron/crontabs/root
grep "systemctl restart ict" /etc/crontab && sed -i 's/^.*systemctl restart ict.*$//' /etc/crontab

systemctl daemon-reload
systemctl enable ict

systemctl restart ict
journalctl -fu ict
