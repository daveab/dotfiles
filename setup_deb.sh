#!/bin/bash
#
# Poached from: Chris Gilbert
#
# This script downloads, builds and installs all packages required for a C++
# developer.
#
# For Debian based systems (including Ubuntu)
#
. setup_cpp_common.sh

# ==============================================================================
# MAIN
# ==============================================================================

check-sudo

echo "========================================================================="
echo 'Developer Setup'
echo "========================================================================="
echo "# Hostname   : "$(hostname)
echo "# O/S        : "$(uname -s -r -v -m)
echo "# Date       : "$(date)
echo "# CPUs       : "$(num-cpus)
echo "========================================================================="

#
# Install packages
#

PACKAGES=(
	# essential tools
	build-essential
	autoconf
	doxygen
	libtool
	swig

	# java jdk (jni, zookeeper)
	#openjdk-6-jdk
	openjdk-7-jdk
	ant
	maven

	# source control
	git
	mercurial
	subversion

	# gcc 4.7
	#gcc-4.7
	#g++-4.7
	g++-4.8
	gcc-4.8
	gcc-4.8-doc
)

	# essential libs
xx_PACKAGES=(
	python-dev
	libicu-dev
	zlib1g-dev
	libbz2-dev
	liblog4cxx10-dev
	libcurl4-openssl-dev
	libcppunit-dev
	uuid-dev
	libmysql++-dev
	libpcre3-dev
	libpcre++-dev
	libevent-dev
	libmecab-dev

	# python
	python-all
	python-all-dev
	python-virtualenv
	python-pip
)

echo "Installing packages..."
apt-get -qy install ${PACKAGES[@]}

exit
setup-work-dir
download-archives
install-third-party
finalize-install
