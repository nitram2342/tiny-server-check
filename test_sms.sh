#!/bin/sh

SMS_CLIENT=/usr/local/bin/simple_fax_sms

. ./config.inc

echo "Tiny Server Check: This is a single test message." | \
    ${SMS_CLIENT} --user "${SIMPLEFAXDE_USER}" --phone "${PHONE_NUM}" --stdin --quiet
