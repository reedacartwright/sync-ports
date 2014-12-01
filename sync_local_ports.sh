#!/bin/sh
# Copyright (c) 2014 Reed A. Cartwright <cartwright@asu.edu>
#
# This script determines the revision number used to build FreeBSD packages
# and syncs a local ports directory to match it.
#
# USAGE: sync_local_ports.sh [name or abs_path]
#
# Requirements: textproc/jq, ports-mgmt/poudriere

SERVER=beefy2.isc.freebsd.org
JAIL=10amd64-default

URL="http://${SERVER}/data/${JAIL}/.data.json"

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

PORTSTREE=$1
if [ -z "$PORTSTREE" ]; then
    PORTSTREE="default"
fi

# If the argument is not an absolute path, use poudriere to resolve it.
# We test for absolute path by seeing if it begins with a slash.
if [ "${PORTSTREE#/}" != "${PORTSTREE}" ]; then
	PORTSDIR="${PORTSTREE}"
else
	PORTSDIR=`poudriere ports -ql | awk "\\\$1 == \"${PORTSTREE}\" { print \\\$3 }"`
fi

if [ ! -d "${PORTSDIR}" ]; then
	>&2 echo "ERROR: Unable to resolve ports tree '${PORTSTREE}' to a directory."
	exit 1
fi

JSON=`fetch -qo - $URL`
if [ $? -gt 0 ]; then
	>&2 echo "ERROR: Unable to fetch data from package server."
	exit 1
fi

REV=`echo "${JSON}" | jq -r '.builds[.builds.latest].svn_url | split("@")[1]'`

if expr "$REV" : '^[[:digit:]][[:digit:]]*$' >/dev/null; then
	svnlite up -r "${REV}" "${PORTSDIR}"
else
	>& echo "ERROR: Unable to determine revision number for latest packages."
	exit 1
fi
