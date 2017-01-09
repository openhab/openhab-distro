#!/bin/bash
#
# Publish p2 repo to bintray
# Usage: publish-bintray.sh user owner apikey  
#
BINTRAY_URL=https://api.bintray.com/
BINTRAY_REPO=mvn
BINTRAY_PACKAGE=online-repo
PACKAGE_VERSION=${online.repo.version}
PACKAGE_ARCHIVE=online-repo-${project.version}.zip
PACKAGE_PATH=online-repo/$PACKAGE_VERSION

if [ "x$1" != "x" ]; then
    BINTRAY_SUBJECT=$1
fi
if [ "x$2" != "x" ]; then
    BINTRAY_USER=$2
fi
if [ "x$3" != "x" ]; then
    BINTRAY_API_KEY=$3
fi


DIRNAME=`dirname "$0"`

function main() {

  cd $DIRNAME

  echo "Creating version $PACKAGE_VERSION ..."
  response=$(curl -s -X POST -u ${BINTRAY_USER}:${BINTRAY_API_KEY} $BINTRAY_URL/packages/$BINTRAY_SUBJECT/$BINTRAY_REPO/$BINTRAY_PACKAGE/versions -d "{ \"name\": \"${PACKAGE_VERSION}\", \"desc\": \"Release ${PACKAGE_VERSION}\" }" -H "Content-Type: application/json")
  if [[ $response == *"ordinal"* ]]
  then
    echo "Version created: $response"
  elif [[ $response == *"already exists"* ]]
  then
    echo "Version exists: $response"
  else
    echo "Failed to create version: $response"
    exit 1;
  fi

  echo "Uploading archive $PACKAGE_ARCHIVE"
  response=$(curl -s -X PUT --data-binary @$PACKAGE_ARCHIVE -u ${BINTRAY_USER}:${BINTRAY_API_KEY} "$BINTRAY_URL/content/$BINTRAY_SUBJECT/$BINTRAY_REPO/$PACKAGE_PATH/addons.zip;bt_package=$BINTRAY_PACKAGE;bt_version=$PACKAGE_VERSION;publish=1;explode=1;override=1" -H "Content-Type: application/zip")
  if [[ $response == *"success"* ]]
  then
    echo "Archive uploaded: $response"
  elif [[ $response == *"No files will be signed"* ]]
  then
    echo "Archive uploaded without signature: $response"
  else
    echo "Error uploading: $response"
    exit 1;
  fi
}

main "$@"

