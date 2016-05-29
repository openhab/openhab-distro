#!/bin/bash

# bintray repo setup for a new version:
# - use the web interface to add the new versions: e.g. 2.0.0b3
# - build openHAB: mvn clean install
# - cd into distributions/distribution-resources/src/main/resources/bin
# - call this script to upload the files:
#     bintray-upload-debs.sh theoweiss 9999999999999999999999999 gpgsecret 2.0.0 stable
#     bintray-upload-debs.sh theoweiss 9999999999999999999999999 gpgsecret 2.0.0b3 testing

showUsageAndExit () {
	echo $@
	echo "usage: $0 <username> <apikey> <gpgpasswd> <version> <distribution>"
	echo "       username: bintray username"
	echo "       apikey: bintray apikey"
	echo "       gpgpasswd: password of the gpg key"
	echo "       version: openhab version"
	echo "       distribution: stable (release), testing (release candidate) or unstable (snapshot)"
	exit 2
}

if [ $# -eq 5 ]; then
	username="$1"
	apikey="$2"
	gpgpasswd="$3"
	version="$4"
	distribution="$5"
	case "$distribution" in
		stable|testing|unstable) : ;;
		*) showUsageAndExit ;;
	esac
else
	showUsageAndExit
fi

DRY_RUN=false
#SUBSCRIPTION=theoweiss
SUBSCRIPTION=openhab
BASE_URL="https://api.bintray.com/content/${SUBSCRIPTION}"
BINTRAY_REPO="apt-repo2"
BINTRAY_PACKAGE="openhab2"
BINTRAY_VERSION="${version}"
for debfile in ../../../../../openhab-offline/target/*.deb ../../../../../openhab-online/target/*.deb; do
	ls ${debfile}
	debfilename=`basename ${debfile}`
	if [ $DRY_RUN = "false" ]; then
		msg=`curl -H "X-GPG-PASSPHRASE: ${gpgpasswd}" -T ${debfile} -u${username}:${apikey} "${BASE_URL}/${BINTRAY_REPO}/${BINTRAY_PACKAGE}/${BINTRAY_VERSION}/pool/main/${version}/${debfilename};deb_distribution=${distribution};deb_distribution=${version};deb_component=main;deb_architecture=all;publish=1" 2>/dev/null`
		echo $msg | awk -F ":" '{ if ( $2 == "\"success\"}" )  exit 0 ; else { print $0 ; exit 1 }} '
		if [ $? -eq 0 ]; then
			echo "ok"
		else
			echo "failed"
			exit 1
		fi
	else
		echo "${BASE_URL}/${BINTRAY_REPO}/${BINTRAY_PACKAGE}/${BINTRAY_VERSION}/pool/main/${version}/${debfilename};deb_distribution=${distribution};deb_distribution=${version};deb_component=main;deb_architecture=all;publish=1"
	fi
done
if [ $DRY_RUN = "false" ]; then
	curl -X POST -H "X-GPG-PASSPHRASE: ${gpgpasswd}" -u${username}:${apikey} https://api.bintray.com/calc_metadata/${SUBSCRIPTION}/${BINTRAY_REPO}
else
	echo "X-GPG-PASSPHRASE: ${gpgpasswd}" -u${username}:${apikey} https://api.bintray.com/calc_metadata/${SUBSCRIPTION}/${BINTRAY_REPO}
fi
