#/bin/sh

ICTHOME="/home/ict"
ICTDIR="omega-ict"
GITREPO="iotaledger/ict"

if [ -z "$1" ] || [ "$1" != "BUILD" -a "$1" != "RELEASE" ] ; then
	echo 'Please choose between BUILD or RELEASE:'
    echo './$0 BUILD|RELEASE [NODENAME]'
    exit
fi

PKGMANAGER=$( command -v apt-get || command -v yum || command -v dnf || command -v emerge || command -v pkg ) || exit "Cannot find the appropriate package manager"

${PKGMANAGER} update
${PKGMANAGER} upgrade -y
${PKGMANAGER} -u curl wget || ${PKGMANAGER} install -y curl wget

useradd -d ${ICTHOME} -m -s /bin/bash ict
mkdir -p ${ICTHOME}/${ICTDIR}
cd ${ICTHOME}/${ICTDIR}

if [ "$1" = "BUILD" ]; then
	case "$PKGMANAGER" in
	*apt-get* )
		${PKGMANAGER} install -y git gnupg dirmngr gradle
		grep "^deb .*webupd8team" /etc/apt/sources.list || echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list
		grep "^deb-src .*webupd8team" /etc/apt/sources.list || echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" >> /etc/apt/sources.list
		apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C2518248EEA14886
		apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886
		apt-get update
		apt-get upgrade -y
		echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
		echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
		apt-get install oracle-java8-installer oracle-java8-set-default -y --allow-unauthenticated
		;;
	* )
		${PKGMANAGER} -u git unzip || ${PKGMANAGER} install -y git unzip
		version=$(javac -version 2>&1)
		if [ "$version" != "javac 1.8.0_192" ] ; then 
			cd /tmp
			wget https://raw.githubusercontent.com/metalcated/scripts/master/install_java.sh -O -  | sed -e 's/^JAVA_TYPE="jre"/JAVA_TYPE="jdk"/' | sh
		fi
		gradle_version=2.10
		if [ ! -d /opt/gradle-${gradle_version} ] ; then
			wget -c http://services.gradle.org/distributions/gradle-${gradle_version}-all.zip
			unzip -o gradle-${gradle_version}-all.zip -d /opt
			ln -s /opt/gradle-${gradle_version} /opt/gradle
			printf "export GRADLE_HOME=/opt/gradle\nexport PATH=\$PATH:\$GRADLE_HOME/bin\n" > /etc/profile.d/gradle.sh
		fi
		source /etc/profile.d/gradle.sh
		;;
	esac
	
	if [ -d ${ICTHOME}/${ICTDIR}/ict/.git ]; then
		cd ${ICTHOME}/${ICTDIR}/ict
		git pull
	else
		cd ${ICTHOME}/${ICTDIR}
		git clone https://github.com/${GITREPO}
	fi
	cd ${ICTHOME}/${ICTDIR}/ict
	rm -f *.jar
	gradle fatJar || exit "BUILD did not work. Try ./$0 RELEASE [NODENAME]"
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
java -jar ${ICTHOME}/${ICTDIR}/ict/ict-${VERSION}.jar &
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

if [ -n "$2" ] ; then
	echo "Setting name of the node to $2"
	sed -i "s/^name=.*$/name=$2/" ict.cfg
fi

cp -f ${ICTHOME}/config/ict.cfg ${ICTHOME}/config/ict.cfg.last
cp -f ict.cfg ${ICTHOME}/config/ict.cfg
chown -R ict ${ICTHOME}/config ${ICTHOME}/${ICTDIR}

if [ ! -z `which systemctl` ] ; then
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
elif [ -f /sbin/openrc-run ] ; then 
	cat <<EOF > /etc/init.d/ict
#!/sbin/openrc-run

name="ict daemon"
description="IOTA ict node"
command="${ICTHOME}/run-ict.sh"
pidfile=/var/run/ict.pid

depend() {
  need net
  use logger dns
}

start() {
  ebegin "Starting ICT"
  start-stop-daemon --start -u ict -d ${ICTHOME}/${ICTDIR} \\
    -1 /var/log/ict.log \\
    --exec \${command} \${command_args} \\
    -b -m --pidfile \${pidfile}
  eend \$?
}

stop() {
  ebegin "Stopping ICT"
  start-stop-daemon --stop -u ict
  eend \$?
}
EOF
	
	chmod u+x /etc/init.d/ict
	
	grep "ict restart" /var/spool/cron/crontabs/root && sed -i 's/^.*ict restart.*$//' /var/spool/cron/crontabs/root
	grep "ict restart" /etc/crontab && sed -i 's/^.*ict restart.*$//' /etc/crontab
	
	rc-update add ict
	/etc/init.d/ict restart
	tail -f /var/log/ict.log
else
	echo "NOT INSTALLED AS SERVICE. STARTING IN FORGROUND."
	${ICTHOME}/run-ict.sh
fi
