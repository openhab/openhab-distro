#!/bin/bash
#
# Publish p2 repo to artifactory
# Usage: publish-artifactory.sh user apikey  
#
ARTIFACTORY_URL=${online.repo}
ARTIFACTORY_PACKAGE=online-repo
PACKAGE_ARCHIVE=online-repo-${project.version}.zip

if [ "x$1" != "x" ]; then
    ARTIFACTORY_USER=$1
fi
if [ "x$2" != "x" ]; then
    ARTIFACTORY_API_KEY=$2
fi


DIRNAME=`dirname "$0"`

function main() {

  cd $DIRNAME

  echo "Uploading archive $PACKAGE_ARCHIVE"
  response=$(curl -s -u ${ARTIFACTORY_USER}:${ARTIFACTORY_API_KEY} -H "X-Explode-Archive-Atomic: true" -X PUT "${ARTIFACTORY_URL}/repo.zip" -T ${PACKAGE_ARCHIVE} )
  echo "Upload finished: $response"
}

main "$@"
