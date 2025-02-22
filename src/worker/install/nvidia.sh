#!/bin/bash

set -e

# install dependencies
source $(dirname "${BASH_SOURCE[0]}")/common.sh


distro=`awk -F= '/^NAME/{print $2}' /etc/os-release`
echo $distro

ubuntu_dcgm_install () {
  		echo "Installing Dcgm"
		apt-get update \
    		&& sudo apt-get install -y datacenter-gpu-manager
}

alma_dcgm_install () {
		echo "Installing Dcgm"
		DCGM_VERSION=2.4.4
		DCGM_URL=https://azhpcstor.blob.core.windows.net/azhpc-images-store/datacenter-gpu-manager-${DCGM_VERSION}-1-x86_64.rpm
		wget --retry-connrefused --tries=3 --waitretry=5 $DCGM_URL
		FILE_NAME=$(basename $DCGM_URL)
		RLINK=$(readlink -f $FILE_NAME)
		Check="1d8fbe97797fada8048a7832bfac4bc7d3ad661bb24163d21324965ae7e7817d"
		checksum=`sha256sum $RLINK | awk '{print $1}'`
		if [[ $checksum != $Check ]]
		then
			echo "*** Error - Checksum verification failed"
			echo "*** Error - Checksum verification failed" > dcgm_fail.log
			exit -1
		fi
		rpm -i datacenter-gpu-manager-${DCGM_VERSION}-1-x86_64.rpm
		rm -f datacenter-gpu-manager-${DCGM_VERSION}-1-x86_64.rpm
}

check_min_dcgm_ver(){
	DCGM_VER=`dcgmi --version |grep version | awk -F ': ' '{print $2}'`
	REQ_VER=$2
	if [ "$(printf '%s\n' "$REQ_VER" "$DCGM_VER" | sort -V | head -n1)" = "$REQ_VER" ]; then 
			echo "A suitable version of Dcgm is already installed"
	else
			echo "removing old DCGM"
			# remove old version
			if [[ $distro =~ "Ubuntu" ]]; then
				apt -y remove datacenter-gpu-manager
			elif [[ $distro =~ "AlmaLinux" ]]; then
				yum -y remove datacenter-gpu-manager
			fi
			$1
	fi

}


# install DCGM
if [[ $distro =~ "Ubuntu" ]]; then
	dcgm_check=`sudo dpkg-query -l`
	if [[ $dcgm_check =~ "datacenter-gpu-manager" ]]; then
		check_min_dcgm_ver ubuntu_dcgm_install "3.1.6"

	else
		ubuntu_dcgm_install
	fi
elif [[ $distro =~ "AlmaLinux" ]]; then
	dcgm_check=`rpm -qa`
	if [[ $dcgm_check =~ "datacenter-gpu-manager" ]]; then
		check_min_dcgm_ver alma_dcgm_install "2.4.4"
	else
		alma_dcgm_install
	fi
else
	echo "OS version is not supported"
fi

exit 0
