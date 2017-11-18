#!/bin/sh

DIRNAME=`dirname "$0"`
FILE_1=`basename "$0"`
OWNER_1=$(ls -ld $FILE_1 | awk '{print $3}')
FILE_2="${DIRNAME}/runtime/instances/instance.properties"
OWNER_2=$(ls -ld $FILE_2 | awk '{print $3}')

# -----------------------------------------------------------------------------
# Check if this directory has the same owner than
# ./runtime/instances/instance.properties. 
# -----------------------------------------------------------------------------
if [ "$OWNER_1" != "$OWNER_2" ]; then
  echo "Wrong permissions
    '${FILE_1}' and '${FILE_2}' are not owned by the same user.
    Maybe the first start of openHAP was done with a wrong user." 1>&2
fi

# -----------------------------------------------------------------------------
# Start openHAB in debug mode.
# -----------------------------------------------------------------------------
exec "${DIRNAME}/start.sh" debug "${@}"