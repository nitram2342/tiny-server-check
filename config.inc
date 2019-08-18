# -*- shell-script-mode -*-
#
# config
#

# SMS notification
PHONE_NUM=+49XXXXXXXXXXXXXXX
SIMPLEFAXDE_USER=example@example.com
export SIMPLEFAXDE_PASS=XXXXXXXXXXXXXXX


# Do some logging.
#VERBOSE=0

# Do a failure test
#FAILTEST=0


# you may want to set program pathes here if it differs
#NC=/bin/nc
#WGET=/usr/bin/wget
#RM=/bin/rm
#TOUCH=/bin/touch
#MKDIR=/bin/mkdir
#DIG=/usr/bin/dig
#SMS_CLIENT=/usr/local/bin/simple_fax_sms



my_own_tests() {
    
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

}


# End of configuration.