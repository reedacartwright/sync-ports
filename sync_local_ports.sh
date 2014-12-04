#!/bin/sh
# Copyright (c) 2014 Reed A. Cartwright <cartwright@asu.edu>
#
# This script determines the revision number used to build FreeBSD packages
# and syncs a local ports directory to match it. 
#
# USAGE: sync_local_ports.sh [name or abs_path]
#
# REQUIREMENTS: textproc/jq, ports-mgmt/poudriere

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
	PORTSDIR=`poudriere ports -ql | awk -v PT="${PORTSTREE}" '$1 == PT { print $3 }'`
fi

# Check if the directory exists
if [ ! -d "${PORTSDIR}" ]; then
	>&2 echo "ERROR: Unable to resolve ports tree '${PORTSTREE}' to a directory."
	exit 1
fi

# Fetch data from server
JSON=`fetch -qo - $URL`
if [ $? -gt 0 ]; then
	>&2 echo "ERROR: Unable to fetch data from package server."
	exit 1
fi

# Parse Revision information from server
REV=`echo "${JSON}" | jq -r '.builds[.builds.latest].svn_url | split("@")[1]'`

# Check revision information
if expr "$REV" : '^[[:digit:]][[:digit:]]*$' >/dev/null; then
	# Skip update if revisions are in sync
	echo "====>> Updating ports tree '${PORTSTREE}' to revision ${REV}"
	CURREV=`svnlite info "${PORTSDIR}" | grep -e '^Revision:' | sed -e 's|Revision: ||'`
	if [ "${CURREV}" -ne "${REV}" ]; then
		svnlite up -r "${REV}" "${PORTSDIR}"
	fi
else
	>& echo "ERROR: Unable to determine revision number for latest packages."
	exit 1
fi
