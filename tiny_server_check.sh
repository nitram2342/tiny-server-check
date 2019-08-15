#!/bin/sh
# --------------------------------------------------------------
# This script checks server availability by probing some services.
# If a service is down, the script sends a message via SMS. Therfore
# it uses the simple-fax-sms script, you can get from github:
# https://github.com/nitram2342/simple-fax-sms
# A notification is also sent, when the service is up, again.
# This script can be called from cron, for example like this:
#
# $ crontab -e
# */2 * * * * /root/tiny_server_check.sh
#
#
# Author: Martin Schobert <martin@weltregierung.de>
# License is BSD-Non-Military. Please read the LICENSE file.
# --------------------------------------------------------------


#
# Configuration
#

# SMS notification
PHONE_NUM=+49XXXXXXXXXXXXXXX
SIMPLEFAXDE_USER=example@example.com
export SIMPLEFAXDE_PASS=XXXXXXXXXXXXXXX

SMS_CLIENT="/usr/local/bin/simple_fax_sms --user ${SIMPLEFAXDE_USER} --phone ${PHONE_NUM} --stdin --quiet"

# Standard tools
NC=/bin/nc
WGET=/usr/bin/wget
RM=/bin/rm
TOUCH=/bin/touch
MKDIR=/bin/mkdir
DIG=/usr/bin/dig

# Do a failure test
FAILTEST=0

# Uncomment to do some logging.
VERBOSE=0

# Timeout value
TIMEOUT=10

# Where to store states
STATE_DIR=~/.tiny_server_check/

# End of configurtion
# _______________________________________________

TEXT_TO_SEND=""

test_tool() {
    CMD=$1
    
    if [ ! -f ${CMD} ] ; then
	echo "+ Please ensure command ${CMD} exists by installing the corresponding package or adjusting the configuration."
	exit 1
    fi
}

send_sms_and_keep_state() {
    EXIT_CODE=$1
    STATE_FILE=$2
    TEXT_FAIL=$3
    TEXT_OK=$4
    
    if [ ${EXIT_CODE} -ne 0 ] || [ ${FAILTEST} -eq 1 ]
    then
	#echo "Failed"	
	if [ ! -f "${STATE_FILE}" ]
	then
	    TEXT_TO_SEND="${TEXT_TO_SEND}\n${TEXT_FAIL}"
	    ${TOUCH} "${STATE_FILE}"
	fi
    else
	#echo "OK"
	if [ -f "${STATE_FILE}" ]
	then
	    TEXT_TO_SEND="${TEXT_TO_SEND}\n${TEXT_OK}"
	    ${RM} "${STATE_FILE}"
	fi
    fi
	
}

test_smtp() {
    STATE_FILE=$1
    HOST=$2
    EXPECTED=$3
    TEXT_FAIL=$4
    TEXT_OK=$5

    ${NC} -w ${TIMEOUT} ${HOST} 25 | grep "${EXPECTED}" >/dev/null
    send_sms_and_keep_state $? "${STATE_FILE}" "${TEXT_FAIL}" "${TEXT_OK}"
}

test_http() {
    STATE_FILE=$1
    URL=$2
    EXPECTED=$3
    TEXT_FAIL=$4
    TEXT_OK=$5
    
    ${WGET} ${URL} --timeout ${TIMEOUT} -O - 2>/dev/null | grep "${EXPECTED}" >/dev/null
    send_sms_and_keep_state $? "${STATE_FILE}" "${TEXT_FAIL}" "${TEXT_OK}"
}

test_dns() {
    STATE_FILE=$1
    SERVER=$2
    RECORD=$3
    TEXT_FAIL=$4
    TEXT_OK=$5

    ${DIG} @${SERVER} ${RECORD} >/dev/null 2>&1 
    send_sms_and_keep_state $? "${STATE_FILE}" "${TEXT_FAIL}" "${TEXT_OK}"
}


#
# Main script
#

# Check file permissions of this script
if [ $(stat -c %a $0) != 700 ]; then
    echo + Please fix script\'s file permissions to 0700
    exit 1
fi

for tool in ${NC} ${WGET} ${RM} ${TOUCH} ${MKDIR} ${DIG}; do
    test_tool $tool
done


# create own directory for states.
if [ ! -d ${STATE_DIR} ]
then
    ${MKDIR} ${STATE_DIR}
fi

#
# Do availability check
#

[ "$VERBOSE" -eq "1" ] && echo "+ Test DNS"
test_dns ${STATE_DIR}"/.dns" \
	 ns10.example.com www.example.com \
	 "DNS: ns10.example.com is down" \
	 "DNS: ns10.example.com is up"
	 

[ "$VERBOSE" -eq "1" ] && echo "+ Test WWW"
test_http ${STATE_DIR}"/.http" \
	  "https://example.com" "HTML" \
	  "HTTP: example.com is down" \
	  "HTTP: example.com is up"

[ "$VERBOSE" -eq "1" ] && echo "+ Test SMTP"
test_smtp ${STATE_DIR}"/.smtp" \
	  mail.example.com "ESMTP" \
	  "SMTP: example.com is down. Run test: https://mxtoolbox.com/SuperTool.aspx?action=smtp%3amail.example.com" \
	  "SMTP: example .comis up"


# check if there is a message to sent
if [ ! -z "${TEXT_TO_SEND}" ]
then
    [ "$VERBOSE" -eq "1" ] && echo "+ Send notification"
    #echo "${TEXT_TO_SEND}"
    echo "${TEXT_TO_SEND}" | ${SMS_CLIENT}
else
    [ "$VERBOSE" -eq "1" ] && echo "+ Nothing to sent"
fi
