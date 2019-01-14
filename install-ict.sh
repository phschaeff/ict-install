#!/bin/sh

ICTHOME="/home/ict"
ICTDIR="omega-ict"
GITREPO="iotaledger/ict"

if [ "$(id -u)" != "0" ]; then
	echo "Please run as root or sudo ./$0 BUILD|RELEASE|EXPERIMENTAL [NODENAME]."
	exit 1
fi

if [ -z "$1" ] || [ "$1" != "BUILD" -a "$1" != "RELEASE" -a "$1" != "EXPERIMENTAL" ] ; then
	echo "Please choose between BUILD or RELEASE:"
    echo "./$0 BUILD|RELEASE|EXPERIMENTAL [NODENAME]"
    exit 1
fi

PKGMANAGER=$( command -v apt-get || command -v yum || command -v dnf || command -v emerge || command -v pkg ) || exit "Cannot find the appropriate package manager"
echo "### Setting package manager to ${PKGMANAGER}"

${PKGMANAGER} update -y
${PKGMANAGER} upgrade -y
${PKGMANAGER} -u curl wget unzip 2>/dev/null || ${PKGMANAGER} install -y curl wget unzip 

echo "### Setting time, preparing user and directories"
date --set="$(curl -v --insecure --silent https://google.com/ 2>&1 | grep -i "^< date" | sed -e 's/^< date: //i')"
useradd -d ${ICTHOME} -m -s /bin/bash ict
mkdir -p ${ICTHOME}/${ICTDIR}
cd ${ICTHOME}/${ICTDIR}

if [ "$1" = "BUILD" -o "$1" = "EXPERIMENTAL" ]; then
	echo "### Installing dependencies for BUILD" 
	case "$PKGMANAGER" in
	*apt-get* )
		${PKGMANAGER} install -y --fix-missing git gnupg dirmngr gradle net-tools
		version=$(javac -version 2>&1)
		if [ "$version" != "javac 1.8.0_191" ] ; then 
			grep "^deb .*webupd8team" /etc/apt/sources.list || echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" >> /etc/apt/sources.list
			grep "^deb-src .*webupd8team" /etc/apt/sources.list || echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu precise main" >> /etc/apt/sources.list
			apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C2518248EEA14886
			apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886
			apt-get update
			apt-get upgrade -y
			echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
			echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
			apt-get install oracle-java8-installer oracle-java8-set-default nodejs npm -y --allow-unauthenticated
		fi
		if [ "$1" = "EXPERIMENTAL" ]; then
			${PKGMANAGER} install -y --fix-missing maven libzmq3-dev pkg-config
			curl https://sh.rustup.rs -sSf | sh -s -- -y 
			source ~/.cargo/env || export PATH="/root/.cargo/bin:$PATH"
		fi
		;;
	* )
		${PKGMANAGER} -u git net-tools maven nodejs npm 2>/dev/null || ${PKGMANAGER} install -y git net-tools nodejs npm
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
		if [ "$1" = "EXPERIMENTAL" ]; then
			exit "### Currently not supported"
		fi
		;;
	esac
	
	echo "### Pulling and building ICT source"
	if [ -d ${ICTHOME}/${ICTDIR}/ict/.git ]; then
		cd ${ICTHOME}/${ICTDIR}/ict
		git pull
		git branch dev
	else
		cd ${ICTHOME}/${ICTDIR}
		rm -rf ict
		git clone https://github.com/${GITREPO}
		cd ict
		git branch dev
	fi
	cd ${ICTHOME}/${ICTDIR}/ict
	rm -f *.jar
	#echo "org.gradle.java.home=/usr/java/jdk1.8.0_192-amd64" > gradle.properties
	gradle fatJar || exit "BUILD did not work. Try ./$0 RELEASE [NODENAME]"
	VERSION=`ls *.jar | sed -e 's/ict\(.*\)\.jar/\1/'`
	echo "### Installing Node.js modules required by ICT"
	cd ${ICTHOME}/${ICTDIR}/ict/web && npm install
	echo "### Done building ICT$VERSION"
	
	echo "### Pulling and building Report.ixi source"
	if [ -d ${ICTHOME}/${ICTDIR}/Report.ixi/.git ]; then
		cd ${ICTHOME}/${ICTDIR}/Report.ixi
		git pull
		git branch dev
	else
		cd ${ICTHOME}/${ICTDIR}
		rm -rf ${ICTHOME}/${ICTDIR}/Report.ixi
		git clone https://github.com/trifel/Report.ixi
		cd Report.ixi
		git branch dev
	fi
	cd ${ICTHOME}/${ICTDIR}/Report.ixi
	rm -f *.jar
	#echo "org.gradle.java.home=/usr/java/jdk1.8.0_192-amd64" > gradle.properties
	gradle fatJar
	REPORT_IXI_VERSION=`ls *.jar | sed -e 's/report.ixi\(.*\)\.jar/\1/'`
	echo "### Done building Report.ixi$REPORT_IXI_VERSION"
	
	echo "### Pulling and building Chat.ixi source"
	cd ${ICTHOME}/${ICTDIR}
	if [ -d ${ICTHOME}/${ICTDIR}/chat.ixi/.git ]; then
		cd ${ICTHOME}/${ICTDIR}/chat.ixi
		git pull
		git branch dev
	else
		cd ${ICTHOME}/${ICTDIR}
		rm -rf ${ICTHOME}/${ICTDIR}/chat.ixi
		git clone https://github.com/iotaledger/chat.ixi
		cd chat.ixi
		git branch dev
	fi
	cd ${ICTHOME}/${ICTDIR}/chat.ixi
	rm -f *.jar
	#echo "org.gradle.java.home=/usr/java/jdk1.8.0_192-amd64" > gradle.properties
	gradle Jar
	mv build/libs/*.jar .
	CHAT_IXI_VERSION=`ls *.jar | sed -e 's/chat.ixi\(.*\)\.jar/\1/'`
	echo "### Done building Chat.ixi$CHAT_IXI_VERSION"
	
	if [ "$1" = "EXPERIMENTAL" ]; then
		echo "### Pulling and building ZeroMQ.ixi source"
		cd ${ICTHOME}/${ICTDIR}
		if [ -d ${ICTHOME}/${ICTDIR}/iota-ixi-zeromq/.git ]; then
			cd ${ICTHOME}/${ICTDIR}/iota-ixi-zeromq
			rm -rf ${ICTHOME}/${ICTDIR}/iota-ixi-zeromq/target
			git pull
		else
			cd ${ICTHOME}/${ICTDIR}
			rm -rf ${ICTHOME}/${ICTDIR}/iota-ixi-zeromq
			git clone https://gitlab.com/Stefano_Core/iota-ixi-zeromq.git
		fi
		cd ${ICTHOME}/${ICTDIR}
		if [ -d ${ICTHOME}/${ICTDIR}/iota-ict-zmq-listener/.git ]; then
			cd ${ICTHOME}/${ICTDIR}/iota-ict-zmq-listener
			git pull
		else
			cd ${ICTHOME}/${ICTDIR}
			rm -rf ${ICTHOME}/${ICTDIR}/iota-ict-zmq-listener
			git clone https://gitlab.com/Stefano_Core/iota-ict-zmq-listener.git
		fi
		cd ${ICTHOME}/${ICTDIR}/iota-ict-zmq-listener/
		npm install && echo "### Done building ICT-ZMQ-Listener"

		echo "### Pulling and building ictmon.ixi source"
		cd ${ICTHOME}/${ICTDIR}
		if [ -d ${ICTHOME}/${ICTDIR}/ictmon/.git ]; then
			cd ${ICTHOME}/${ICTDIR}/ictmon
			git pull
		else
			cd ${ICTHOME}/${ICTDIR}
			rm -rf ${ICTHOME}/${ICTDIR}/ictmon
			git clone https://github.com/Alex6323/ictmon.git
		fi
		cd ${ICTHOME}/${ICTDIR}/ictmon/ 
		cargo build --release && echo "### Done building ictmon.ixi"
	fi
fi

if [ "$1" = "RELEASE" ]; then
	echo "### Installing dependencies for RELEASE"
	version=$(javac -version 2>&1)
	if [ "$version" != "javac 1.8.0_191" ] ; then
		case "$PKGMANAGER" in
		*apt-get* )
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
		*emerge* )
			emerge -u virtual/jre
			;;
		* )
			cd /tmp
			wget https://raw.githubusercontent.com/metalcated/scripts/master/install_java.sh -O -  | sed -e 's/^JAVA_TYPE="jre"/JAVA_TYPE="jdk"/' | sh
			;;
		esac
	fi
	cd ${ICTHOME}/${ICTDIR}
	VERSION=`curl --silent "https://api.github.com/repos/${GITREPO}/releases" | grep '"tag_name":' |head -1 | sed -E 's/.*"([^"]+)".*/\1/'`
	if [ ! -f ict/ict-${VERSION}.jar ]; then
			mkdir ict
			cd ict
			rm -f *.jar
			wget -c https://github.com/iotaledger/ict/releases/download/${VERSION}/ict-${VERSION}.jar
	fi
	VERSION="-${VERSION}"
	echo "### Done downloading ICT$VERSION"
	cd ${ICTHOME}/${ICTDIR}
	REPORT_IXI_VERSION=`curl --silent "https://api.github.com/repos/trifel/Report.ixi/releases" | grep '"tag_name":' |head -1 | sed -E 's/.*"([^"]+)".*/\1/'`
	if [ ! -f Report.ixi/report.ixi-${REPORT_IXI_VERSION}.jar ]; then
			mkdir Report.ixi
			cd Report.ixi
			rm -f *.jar *.zip
			wget -c https://github.com/trifel/Report.ixi/releases/download/${REPORT_IXI_VERSION}/report.ixi-${REPORT_IXI_VERSION}.jar
	fi
	REPORT_IXI_VERSION="-${REPORT_IXI_VERSION}"
	echo "### Done downloading Report.ixi$REPORT_IXI_VERSION"
	cd ${ICTHOME}/${ICTDIR}
	CHAT_IXI_VERSION=`curl --silent "https://api.github.com/repos/iotaledger/chat.ixi/releases" | grep '"tag_name":' |head -1 | sed -E 's/.*"([^"]+)".*/\1/'`
	if [ ! -f chat.ixi/chat.ixi-${CHAT_IXI_VERSION}.jar ]; then
			mkdir chat.ixi
			cd chat.ixi
			rm -f *.jar *.zip
			wget -c https://github.com/iotaledger/chat.ixi/releases/download/${CHAT_IXI_VERSION}/chat.ixi-${CHAT_IXI_VERSION}.jar
	fi
	CHAT_IXI_VERSION="-${CHAT_IXI_VERSION}"
	echo "### Done downloading Chat.ixi$CHAT_IXI_VERSION"
fi

echo "### Preparing directories, run script, and configs"

mkdir -p ${ICTHOME}/config

echo "### Creating default ict.cfg template"
cd ${ICTHOME}/${ICTDIR}
rm -f ict.cfg
java -jar ${ICTHOME}/${ICTDIR}/ict/ict${VERSION}.jar --config-create &
last_pid=$!
while [ ! -f ict.cfg ] ; do sleep 1 ; done
sleep 1
kill -KILL $last_pid 2>/dev/null 1>/dev/null
rm -rf web

if [ ! -f ${ICTHOME}/config/ict.cfg ]; then
	if [ -f ${ICTHOME}/config/ict.properties ]; then
		echo "### Importing from old ict.properties"
		host=`sed -ne 's/^host\s*=\s*//gp' ${ICTHOME}/config/ict.properties`
		port=`sed -ne 's/^port\s*=\s*//gp' ${ICTHOME}/config/ict.properties`
		neighbors=`sed -ne 's/^neighbor\(A\|B\|C\)\(Host\|Port\)\s*=\s*//gp' ${ICTHOME}/config/ict.properties | sed ':a;N;$!ba;s/\n/:/g;s/:\([^:]*\):/:\1,/g'`
		sed -i "s/^host=.*$/host=$host/;s/^port=.*$/port=$port/;s/^neighbors=.*$/neighbors=$neighbors/" ict.cfg
	fi
else
	echo "### Importing from existing ict.cfg"
	grep -v "^#" ${ICTHOME}/config/ict.cfg | while IFS="=" read -r varname value ; do
		echo "### Setting config $varname to ${value}"
		sed -i "s/^$varname=.*$/$varname=$value/" ict.cfg
		cp -f ict.cfg ${ICTHOME}/config/ict.cfg
	done
fi

if [ /bin/true ]; then
	echo "### Adapting run script and configs for IXIs"
	cat <<EOF > ${ICTHOME}/run-ict.sh
#!/bin/sh
cd ${ICTHOME}/${ICTDIR}
java -jar ${ICTHOME}/${ICTDIR}/ict/ict${VERSION}.jar -c ${ICTHOME}/config/ict.cfg &
ict_pid=\$!
echo \$ict_pid > ict.pid
EOF
	cat <<EOF > ${ICTHOME}/stop-ict.sh
#!/bin/sh
cd ${ICTHOME}/${ICTDIR}
kill \$(cat ${ICTHOME}/${ICTDIR}/ict.pid)
EOF
	chmod a+x ${ICTHOME}/run-ict.sh ${ICTHOME}/stop-ict.sh
	cd ${ICTHOME}/${ICTDIR}
	cp -f ${ICTHOME}/${ICTDIR}/Report.ixi/report.ixi${REPORT_IXI_VERSION}.jar ${ICTHOME}/${ICTDIR}/modules/report.ixi${REPORT_IXI_VERSION}.jar
	echo "### Creating default report.ixi.cfg template"
	echo "name=nick (ict-0)" > report.ixi.cfg
	echo "neighbors=127.0.0.1\:1338" >> report.ixi.cfg
	echo "reportPort=1338" >> report.ixi.cfg
	echo "### Setting config neighbors in report.ixi.cfg"
	neighbors=`sed -ne 's/:[[:digit:]]\+/:1338/g;s/^neighbors\s*=\s*//gp' ict.cfg`
	sed -i "s/^neighbors=.*$/neighbors=$neighbors/" report.ixi.cfg

	if [ -f ${ICTHOME}/config/report.ixi.cfg -a ! -h ${ICTHOME}/config/report.ixi.cfg ]; then
		echo "### Importing from old report.ixi.cfg"
		grep -v "^#" ${ICTHOME}/config/report.ixi.cfg | while IFS="=" read -r varname value ; do
			echo "### Setting config $varname to ${value} in report.ixi.cfg"
			sed -i "s/^$varname=.*$/$varname=$value/" report.ixi.cfg
		done
		if [ `grep -c "^neighbor[A|B|C][Host|Port]" report.ixi.cfg` -gt 0 ] && [ `grep -c "^neighbors=[^[:space:]+]" report.ixi.cfg` -eq 0 ]  ; then 
			neighbors=`sed -ne 's/^neighbor\(A\|B\|C\)\(Host\|Port\)\s*=\s*//gp' ../config/report.ixi.cfg | sed ':a;N;$!ba;s/\n/:/g;s/:\([^:]*\):/:\1,/g'`
			echo "### Converting neighbor?Host syntax to $neighbors"
			sed -i "s/^neighbors=.*$/neighbors=$neighbors/" report.ixi.cfg
		fi 
		sed -i "/^neighbor[A|B|C][Host|Port]/d" report.ixi.cfg
		rm -f ${ICTHOME}/config/report.ixi.cfg
	fi
	if [ -f ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg ]; then
		cp -f ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg.last
		echo "### Importing from existing report.ixi.cfg"
		grep -v "^#" ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg | while IFS="=" read -r varname value ; do
			echo "### Setting config $varname to ${value} in report.ixi.cfg"
			sed -i "s/^$varname=.*$/$varname=$value/" report.ixi.cfg
		done
	fi
	if [ -n "$2" ] ; then
		echo "### Setting nodename of the node to $2"
		sed -i "s/^name=.*$/name=$2/" report.ixi.cfg
	fi
	if [ `grep -Ec "^name=[^()]+ \(ict-[[:digit:]]+\)$" report.ixi.cfg` -eq 0 ] ; then
		nodename=""
		while [ `echo "$nodename" | grep -Ec "^[^()]+ \(ict-[[:digit:]]+\)$"` -eq 0 ] ; do
			echo "### Please give your node an individual name. Follow the naming convention: <name> (ict-<number>)"
			read -r nodename
		done
		sed -i "s/^name=.*$/name=$nodename/" report.ixi.cfg
	fi

	mkdir -p ${ICTHOME}/${ICTDIR}/modules/report.ixi
	cp -f report.ixi.cfg ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg
	rm -f ${ICTHOME}/config/report.ixi.cfg
	ln -s ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg ${ICTHOME}/config/
#	sed -i "s/^ixi_enabled=.*$/ixi_enabled=true/" ict.cfg
	rm -f ${ICTHOME}/${ICTDIR}/modules/report.ixi*jar
	cp -f ${ICTHOME}/${ICTDIR}/Report.ixi/report.ixi${REPORT_IXI_VERSION}.jar ${ICTHOME}/${ICTDIR}/modules/report.ixi${REPORT_IXI_VERSION}.jar
	
	if [ -f ${ICTHOME}/config/chat.ixi.cfg -a ! -h ${ICTHOME}/config/chat.ixi.cfg ] ; then
		CHATUSER=`sed -ne "s/^username=\(.*\)$/\1/gp" ${ICTHOME}/config/chat.ixi.cfg`
		RANDOMPASS=`sed -ne "s/^password=\(.*\)$/\1/gp" ${ICTHOME}/config/chat.ixi.cfg`
		rm -f ${ICTHOME}/config/chat.ixi.cfg
	elif [ -f ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg ] ; then
		CHATUSER=`sed -ne "s/^username=\(.*\)$/\1/gp" ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg`
		RANDOMPASS=`sed -ne "s/^password=\(.*\)$/\1/gp" ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg`
	else 
		mkdir -p ${ICTHOME}/${ICTDIR}/modules/chat-config
		CHATUSER=`sed -ne "s/^name=\(.*\) .*$/\1/p" report.ixi.cfg`
		RANDOMPASS=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12`
		#read -e -p "Enter a password for Chat.ixi API:" -i "${CHATUSER}" CHATUSER
		#read -e -p "Enter a password for Chat.ixi API:" -i "${RANDOMPASS}" RANDOMPASS
		echo "username=$CHATUSER" > ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg
		echo "password=$RANDOMPASS" >> ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg
		rm -f ${ICTHOME}/config/chat.ixi.cfg
		ln -s ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg ${ICTHOME}/config/
	fi
	rm -rf ${ICTHOME}/${ICTDIR}/modules/chat.ixi*
	cp -f ${ICTHOME}/${ICTDIR}/chat.ixi/chat.ixi${CHAT_IXI_VERSION}.jar ${ICTHOME}/${ICTDIR}/modules/chat.ixi${CHAT_IXI_VERSION}.jar
	
	if [ "$1" = "EXPERIMENTAL" ]; then
		if [ ! -f ${ICTHOME}/${ICTDIR}/modules/zeromq.ixi/zeromq.ixi.cfg ] ; then
			mkdir -p ${ICTHOME}/${ICTDIR}/modules/zeromq.ixi
			echo "ZMQPORT=5560" > ${ICTHOME}/${ICTDIR}/modules/zeromq.ixi/zeromq.ixi.cfg
			ln -s ${ICTHOME}/${ICTDIR}/modules/zeromq.ixi/zeromq.ixi.cfg ${ICTHOME}/config/
		fi
		rm -f ${ICTHOME}/${ICTDIR}/modules/ixi-zeromq*jar
		cp -f ${ICTHOME}/${ICTDIR}/iota-ixi-zeromq/ixi-zeromq/target/ixi-zeromq-jar-with-dependencies.jar ${ICTHOME}/${ICTDIR}/modules/
	fi
fi

echo "### Writing new configs"
cd ${ICTHOME}/${ICTDIR}
cp -f ${ICTHOME}/config/ict.cfg ${ICTHOME}/config/ict.cfg.last
cp -f ict.cfg ${ICTHOME}/config/ict.cfg 
chown -R ict ${ICTHOME}/config ${ICTHOME}/${ICTDIR}

echo "### Configuring system services"
if [ $(systemctl is-active --quiet systemd-sysctl.service 2>/dev/null; echo $?) -eq 0 ] ; then
	echo "### systemd"
	cat <<EOF > /lib/systemd/system/ict.service
	[Unit]
	Description=IOTA ICT
	After=network.target
	[Service]
	ExecStart=/usr/bin/java -jar ${ICTHOME}/${ICTDIR}/ict/ict${VERSION}.jar -c ${ICTHOME}/config/ict.cfg
	WorkingDirectory=${ICTHOME}/${ICTDIR}
	StandardOutput=inherit
	StandardError=inherit
	Restart=always
	User=ict
	PIDFile=/var/run/ict.pid
	[Install]
	WantedBy=multi-user.target
EOF
	chmod u+x /lib/systemd/system/ict.service
	systemctl daemon-reload
	systemctl enable ict
	systemctl restart ict

	for ixi in $(ls /lib/systemd/system/ict_* | rev | cut -f1 -d"/" | rev) ; do 
		echo "### Removing old ${ixi}"
		systemctl stop ${ixi}
		systemctl disable
		rm -f /lib/systemd/system/${ixi}
	done

	systemctl daemon-reload

	journalctl -f _UID=$(id -u ict)
	
elif [ -f /sbin/openrc-run ] ; then
	echo "### openrc"
	cat <<EOF > /etc/init.d/ict
#!/sbin/openrc-run

name="ict daemon"
description="IOTA ict node"
command="/usr/bin/java"
command_args="-jar ${ICTHOME}/${ICTDIR}/ict/ict${VERSION}.jar -c ${ICTHOME}/config/ict.cfg"
pidfile=/var/run/ict.pid

depend() {
  need net
  use logger dns
}

start() {
  ebegin "Starting ICT"
  start-stop-daemon --start -u ict -d ${ICTHOME}/${ICTDIR} \\
    -1 /var/log/ict.log \\
    --exec \${command} \\
    -b -m --pidfile \${pidfile} \\
    -- \${command_args}

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
	echo "### ict daemon installed, added to boot, and restarted"

	for ixi in $(ls /etc/init.d/ict_* | rev | cut -f1 -d"/" | rev) ; do 
		echo "### Removing old ${ixi} service"
		/etc/init.d/${ixi} stop
		rc-update del ${ixi}
		rm -f /etc/init.d/${ixi}
	done
	
	tail -f /var/log/ict.log

else
	echo "### NOT INSTALLED AS SERVICE. STARTING IN FORGROUND."
	cd ${ICTHOME}/${ICTDIR}
	${ICTHOME}/stop-ict.sh
	sudo --user=ict ${ICTHOME}/run-ict.sh & 
fi
