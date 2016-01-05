#!/bin/sh

echo Launching the openHAB runtime...

DIRNAME=`dirname "$0"`
exec "${DIRNAME}/start.sh" debug "${@}"