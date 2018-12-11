#/bin/sh

if [ -n "$2" ]; then
	ICTHOME="$2"
	else
	ICTHOME="/home/ict"
fi

if [ -z "$1" ] && [ ! -f ${ICTHOME}/config/report.properties ] && [ ! -f ${ICTHOME}/Ict/ixi/Report.ixi/report.properties ]; then
	echo 'Please supply your node name as argument, e.g.: '
	echo './install-IXI.sh "NICKNAME (ict-0)"'
	exit
fi

if [ ! -d ${ICTHOME}/Ict ]; then
	echo "Could not find suitable prior installation of ICT in ${ICTHOME}/Ict"
	echo "Please install ICT first or give ict home dir as 2nd argument, e.g.:"
	echo './install-IXI.sh "NICKNAME (ict-0)" /home/ict'
	exit
fi

cd ${ICTHOME}

VERSION=`curl --silent "https://api.github.com/repos/trifel/Ict/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'`

if [ ! -f Ict/${VERSION}.jar ]; then 
	wget https://github.com/trifel/Ict/releases/download/${VERSION}/${VERSION}.tar.gz
	tar xzf ${VERSION}.tar.gz Ict/${VERSION}.jar

	cat <<EOF > ${ICTHOME}/Ict/run-ict.sh
#!/bin/bash
cd ${ICTHOME}/Ict
java -jar ${VERSION}.jar ${ICTHOME}/config/ict.properties
EOF
fi

if [ ! -f ${ICTHOME}/config/ict.properties ]; then
	mkdir -p ${ICTHOME}/config/
	cp ${ICTHOME}/Ict/ict.properties ${ICTHOME}/config/ict.properties
fi

if [ -d ${ICTHOME}/Ict/ixi ] && [ -f ${ICTHOME}/config/report.properties ]; then
	cd ${ICTHOME}/Ict/ixi/Report.ixi/
	git pull
else
	mkdir -p ${ICTHOME}/Ict/ixi
	cd ${ICTHOME}/Ict/ixi
	git clone https://github.com/trifel/Report.ixi.git
	
	if [ -f ${ICTHOME}/Ict/ixi/Report.ixi/report.properties ] && [ ! -f ${ICTHOME}/config/report.properties ]; then
		cp ${ICTHOME}/Ict/ixi/Report.ixi/report.properties ${ICTHOME}/config/report.properties
	else
		cat <<EOF > ${ICTHOME}/config/report.properties
reportServerHost = 130.211.219.192
reportServerPort = 14265
nodeName = ${1:-NewNode (ict-0)}
nodeExternalPort = 14265
EOF
	fi
	rm -f ${ICTHOME}/Ict/ixi/Report.ixi/report.properties
	ln -s ${ICTHOME}/config/report.properties ${ICTHOME}/Ict/ixi/Report.ixi/report.properties
	chown -R ict ${ICTHOME}/config/report.properties ${ICTHOME}/Ict/ixi
fi

if [ -f /lib/systemd/system/ict.service ]; then
	systemctl restart ict
	journalctl -fu ict
fi


