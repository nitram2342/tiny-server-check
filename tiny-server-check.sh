#!/bin/sh
# --------------------------------------------------------------
# This script checks service and server availability by probing
# some services.
#
# If a service is down, the script sends a message via SMS.
# Therefore, it uses the simple-fax-sms script, you can get from
# github: https://github.com/nitram2342/simple-fax-sms
# A notification is also sent, when the service is up again.
# The up or down state is kept via state files and as long
# as nothing happens, you won't get further messages.
#
# In order to use this script for your own purposes, please:
# - adjust the configuration in the config.inc
# - adjust availability check section in config.inc
# - adjust the notification section if necessary in config.inc
#
# This script can be called from cron, for example like this:
#
# $ crontab -e
# */2 * * * * /home/pi/tiny-server-check/tiny-server-check.sh >/dev/null 2>&1
#
#
# Author: Martin Schobert <martin@weltregierung.de>
# License is BSD-Non-Military. Please read the LICENSE file.
# --------------------------------------------------------------


#
# Standard configuration section -
# settings may be overwritten by config.inc
#


# Tools
SMS_CLIENT=/usr/local/bin/simple_fax_sms
NC=/bin/nc
WGET=/usr/bin/wget
RM=/bin/rm
TOUCH=/bin/touch
MKDIR=/bin/mkdir
DIG=/usr/bin/dig
PING=/bin/ping

# Uncomment to do some logging.
VERBOSE=0

# Do a failure test
FAILTEST=0

# Timeout value
TIMEOUT=10

# time to wait for a recheck after a failed check
WAIT=5

# Where to store states
STATE_DIR=~/.tiny_server_check/

# Allow sending a test message every month at the time specified.
# This requires the script to be called frequently that there is
# a chance to be run at this time. Hours and minutes must be
# written in %02d format.
TEST_SMS=1
TEST_SMS_DAY="01"
TEST_SMS_HOUR="09"
TEST_SMS_MINUTE="00"


# We will check if we are online. If there is no Intenet,
# then all services seem to be down.
HOST_ONLINE_CHECK=8.8.8.8

# End of standard configuration
# _______________________________________________


#
# Load configuatration file
#

CONFIG_FILE="$(dirname "$0")""/config.inc"
. ${CONFIG_FILE}



TEXT_TO_SEND=""

#
# Helper function section
#

test_tool() {
    CMD=$1
    
    if [ ! -f ${CMD} ] ; then
	echo "+ Please ensure command ${CMD} exists by installing the corresponding package or adjusting the configuration."
	exit 1
    fi
}

check_service_state() {
    SERVICE_STATUS=$1
    STATE_FILE=$2
    TEXT_FAIL=$3
    TEXT_OK=$4

    if [ "${VERBOSE}" -eq 1 ] ; then
	echo "+ Check service state"
	echo "  Service status : ${SERVICE_STATUS}"
	echo "  State file     : ${STATE_FILE}"
	echo "  Text fail      : ${TEXT_FAIL}"
	echo "  Text OK        : ${TEXT_OK}"
    fi
    
    if [ ${SERVICE_STATUS} -eq 0 ] || [ "${FAILTEST}" -eq 1 ]
    then
	[ "${VERBOSE}" -eq 1 ] && echo "+ Test failed."

	if [ ! -f "${STATE_FILE}" ]
	then
	    TEXT_TO_SEND="${TEXT_TO_SEND}\n${TEXT_FAIL}"
	    ${TOUCH} "${STATE_FILE}"
	fi
    else
	[ "${VERBOSE}" -eq 1 ] && echo "+ Test is ok."

	if [ -f "${STATE_FILE}" ]
	then
	    TEXT_TO_SEND="${TEXT_TO_SEND}\n${TEXT_OK}"
	    ${RM} "${STATE_FILE}"
	fi
    fi
    
    [ "${VERBOSE}" -eq 1 ] && echo "+ Message text is: ${TEXT_TO_SEND}"
	
}

test_tcp_banner() {
    STATE_FILE=$1
    HOST=$2
    EXPECTED=$3
    TEXT_FAIL=$4
    TEXT_OK=$5
    PORT=$6

    status=1
    counter=0
    
    for i in 1 2 3
    do
	${NC} -w ${TIMEOUT} ${HOST} ${PORT} | grep "${EXPECTED}" >/dev/null
	if [ $? -ne 0 ]
	then
	    # failed, try again
	    sleep ${WAIT}
	    counter=$((counter+1))
	else
	    break
	fi
    done

    [ "$counter" -eq 3 ] && status=0
       
    check_service_state ${status} "${STATE_FILE}" "${TEXT_FAIL}" "${TEXT_OK}"
}

test_smtp() {
    STATE_FILE=$1
    HOST=$2
    EXPECTED=$3
    TEXT_FAIL=$4
    TEXT_OK=$5
    PORT=${6-25}
    test_tcp_banner "${STATE_FILE}" "${HOST}" "${EXPECTED}" "${TEXT_FAIL}" "${TEXT_OK}" "${PORT}"
}

test_ssh() {
    STATE_FILE=$1
    HOST=$2
    EXPECTED=$3
    TEXT_FAIL=$4
    TEXT_OK=$5
    PORT=${6-22}
    test_tcp_banner "${STATE_FILE}" "${HOST}" "${EXPECTED}" "${TEXT_FAIL}" "${TEXT_OK}" "${PORT}"
}

test_http() {
    STATE_FILE=$1
    URL=$2
    EXPECTED=$3
    TEXT_FAIL=$4
    TEXT_OK=$5
    
    status=1
    counter=0
    
    for i in 1 2 3
    do
	${WGET} ${URL} --timeout ${TIMEOUT} -O - 2>/dev/null | grep "${EXPECTED}" >/dev/null
	if [ $? -ne 0 ]
	then
	    # failed, try again
	    sleep ${WAIT}
	    counter=$((counter+1))
	else
	    break
	fi
    done

    [ "$counter" -eq 3 ] && status=0
       
    check_service_state ${status} "${STATE_FILE}" "${TEXT_FAIL}" "${TEXT_OK}"
}

test_dns() {
    STATE_FILE=$1
    SERVER=$2
    RECORD=$3
    TEXT_FAIL=$4
    TEXT_OK=$5

    status=1
    counter=0
       
    for i in 1 2 3
    do
	${DIG} @${SERVER} ${RECORD} >/dev/null 2>&1
	if [ $? -ne 0 ]
	then
	    # failed, try again
	    sleep ${WAIT}
	    counter=$((counter+1))
	else
	    break
	fi
    done

    [ "$counter" -eq 3 ] && status=0
       
    check_service_state ${status} "${STATE_FILE}" "${TEXT_FAIL}" "${TEXT_OK}"
}


test_online_or_exit() {
    
    ${PING} -q -c 2 ${HOST_ONLINE_CHECK} >/dev/null 2>&1
    if [ $? -eq 0 ]
    then
       [ "${VERBOSE}" -eq 1 ] && echo "+ We are online."
    else
       [ "${VERBOSE}" -eq 1 ] && echo "+ We are offline."
       exit
    fi
}


#
# Main script
#

# Check file permissions of the config file to not leak
# credentials. The check does not look up the file owner
# and hence is only a minimal check.
if [ $(stat -c %a ${CONFIG_FILE}) != 600 ]; then
    echo + Please fix config file permissions to 0600
    exit 1
fi

# Check if helper tools exist. If a tool does not exist, the program stops.
for tool in ${NC} ${WGET} ${RM} ${TOUCH} ${MKDIR} ${DIG} ${SMS_CLIENT} ${PING}; do
    test_tool $tool
done


# Create own directory for states.
if [ ! -d ${STATE_DIR} ]
then
    ${MKDIR} ${STATE_DIR}
fi

# Start with an online/offline check.
test_online_or_exit

# Check if we should send a monthly test message
DAY=`date +"%d"`
HOUR=`date +"%H"`
MINUTE=`date +"%M"`
if [ "${TEST_SMS}" -eq 1 ] && \
       [ "${DAY}" -eq "${TEST_SMS_DAY}" ] && \
       [ "${HOUR}" -eq "${TEST_SMS_HOUR}" ] && \
       [ "${MINUTE}" -eq "${TEST_SMS_MINUTE}" ] ; then
    
    echo "Tiny Server Check: This is the monthly test message." | \
	${SMS_CLIENT} --user "${SIMPLEFAXDE_USER}" --phone "${PHONE_NUM}" --stdin --quiet
fi


[ "${VERBOSE}" -eq 1 ] && echo "+ FAILTEST: ${FAILTEST}"

#
# Availability check section
#

my_own_tests

# End of availability checks
# _______________________________________________


#
# Notification section
#

# check if there is a message to sent
if [ ! -z "${TEXT_TO_SEND}" ] || [ "${FAILTEST}" -eq 1 ]
then

    if [ -z "${TEXT_TO_SEND}" ] ; then
	TEXT_TO_SEND="FAILTEST mode"
    fi
    
    [ "${VERBOSE}" -eq 1 ] && echo "+ Send notification:" && echo "${TEXT_TO_SEND}"
    echo "${TEXT_TO_SEND}" | ${SMS_CLIENT} \
				 --user "${SIMPLEFAXDE_USER}" --phone "${PHONE_NUM}" \
				 --stdin --quiet
else
    [ "${VERBOSE}" -eq 1 ] && echo "+ Nothing to sent."
fi

# End of notification
# _______________________________________________
