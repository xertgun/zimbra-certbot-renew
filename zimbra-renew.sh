#!/bin/bash

# ==============================================================================
# Script Name : zimbra-renew.sh
# Description : Automated Let's Encrypt SSL certificate renewal & deployment for Zimbra ZCS
# Author      : EGTA Software (Ertan Günay)
# Repository  : https://github.com/xertgun/zimbra-certbot-renew
# ==============================================================================

# ==============================================================================
# CONFIGURATION AREA
# ==============================================================================
# TEST_MODE=true  -> Runs in dry-run mode (does not consume Let's Encrypt limits, skips zmcontrol restart, sends test email).
# TEST_MODE=false -> Production mode, renews actual certificate and restarts services.
TEST_MODE=true

TO_EMAIL="admin@yourdomain.com"
DOMAIN="mail.yourdomain.com"
# Add your secondary domains separated by space if any (used for proxy configuration)
ADDITIONAL_DOMAINS=("yourdomain.com" "secondarydomain.com")

# Ensure safe PATH for cron and system environments
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Certbot and Sendmail binary paths
CERTBOT_BIN=$(which certbot 2>/dev/null || echo "/usr/bin/certbot")
SENDMAIL_BIN=$(which sendmail || echo "/usr/sbin/sendmail")
ERR_LOG="/tmp/certbot_renew_error.log"
rm -f "$ERR_LOG"

# ==============================================================================
# 0. ROOT / SUDO PRIVILEGE CHECK
# ==============================================================================
if [ "$(id -u)" -ne 0 ]; then
    if [ "$TEST_MODE" = true ]; then
        SUBJECT_PREFIX="[TEST MODE] "
    else
        SUBJECT_PREFIX=""
    fi
    
    echo -e "\n\033[0;31m⛔ ERROR: This script requires root privileges!\033[0m"
    echo -e "\033[1;33mPlease run the script with sudo:\033[0m"
    echo -e "   \033[0;36msudo $0\033[0m\n"

    echo "ERROR: Script executed without root/sudo privileges! Access to Certbot lock file was denied." > "$ERR_LOG"
    ERROR_DETAILS=$(cat "$ERR_LOG" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

    "$SENDMAIL_BIN" -t <<EOF
To: $TO_EMAIL
From: Zimbra Security <zimbra@yourdomain.com>
Subject: =?UTF-8?B?$(echo -n "${SUBJECT_PREFIX} ⛔ ZIMBRA : Privilege Error (Root / Sudo Required)" | base64 -w 0)?=
MIME-Version: 1.0
Content-Type: text/html; charset=UTF-8

<div style="font-family: Arial, sans-serif; background-color: #f4f6f9; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 8px; padding: 25px; border-left: 6px solid #d9534f; box-shadow: 0 2px 5px rgba(0,0,0,0.05);">
    <h2 style="color: #d9534f; margin-top: 0; font-size: 20px;">⛔ SSL Certificate Operation Failed!</h2>
    <p style="color: #444; font-size: 14px; line-height: 1.5;">
      Zimbra Mail Server SSL certificate script was aborted because it was run without proper privileges.
    </p>

    <div style="background-color: #f8f9fa; border: 1px solid #e9ecef; border-radius: 6px; padding: 15px; margin: 20px 0;">
      <table style="width: 100%; font-size: 13px; color: #333;" cellpadding="4">
        <tr>
          <td style="font-weight: bold; width: 35%;">Server Hostname:</td>
          <td>$DOMAIN</td>
        </tr>
        <tr>
          <td style="font-weight: bold;">Timestamp:</td>
          <td>$(date '+%d.%m.%Y %H:%M:%S')</td>
        </tr>
      </table>
    </div>

    <div style="margin-top: 15px;">
      <strong style="color: #d9534f; font-size: 13px;">🔍 Captured Error Detail:</strong>
      <pre style="background-color: #272822; color: #f8f8f2; padding: 12px; border-radius: 6px; font-size: 11px; overflow-x: auto; white-space: pre-wrap; margin-top: 5px;">$ERROR_DETAILS</pre>
    </div>

    <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;">
    <p style="font-size: 11px; color: #888; margin: 0; text-align: center;">Zimbra Automated Server Management System</p>
  </div>
</div>
EOF

    rm -f "$ERR_LOG"
    exit 1
fi

# ==============================================================================
# 1. CERTBOT RENEWAL TEST / PRODUCTION MODE
# ==============================================================================
if [ "$TEST_MODE" = true ]; then
    echo "-----------------------------------------------------------------------"
    echo "⚠️  TEST MODE ACTIVE: Let's Encrypt limits will not be consumed (--dry-run)."
    echo "-----------------------------------------------------------------------"
    CERTBOT_CMD="$CERTBOT_BIN renew --cert-name $DOMAIN --dry-run"
    SUBJECT_PREFIX="[TEST MODE] "
else
    echo "-------------------------------------------------------------------------"
    echo "🚀 PRODUCTION MODE ACTIVE: Real SSL certificate is being renewed..."
    echo "-------------------------------------------------------------------------"
    CERTBOT_CMD="$CERTBOT_BIN renew --cert-name $DOMAIN --pre-hook \"su - zimbra -c '/opt/zimbra/bin/zmproxyctl stop'\" --post-hook \"su - zimbra -c '/opt/zimbra/bin/zmproxyctl start'\" --key-type rsa"
    SUBJECT_PREFIX=""
fi

eval "$CERTBOT_CMD" > "$ERR_LOG" 2>&1
CERT_STATUS=$?

if [ $CERT_STATUS -ne 0 ]; then
    echo "ERROR: Certbot renewal/test process failed!"
    ERROR_DETAILS=$(cat "$ERR_LOG" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

    "$SENDMAIL_BIN" -t <<EOF
To: $TO_EMAIL
From: Zimbra Security <zimbra@yourdomain.com>
Subject: =?UTF-8?B?$(echo -n "${SUBJECT_PREFIX}⛔ ZIMBRA : Certificate Renewal ERROR NOTIFICATION!" | base64 -w 0)?=
MIME-Version: 1.0
Content-Type: text/html; charset=UTF-8

<div style="font-family: Arial, sans-serif; background-color: #f4f6f9; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 8px; padding: 25px; border-left: 6px solid #d9534f; box-shadow: 0 2px 5px rgba(0,0,0,0.05);">
    <h2 style="color: #d9534f; margin-top: 0; font-size: 20px;">⛔ SSL Certificate Operation Failed!</h2>
    <p style="color: #444; font-size: 14px; line-height: 1.5;">
      An error occurred while renewing the Zimbra Mail Server SSL certificate.
    </p>

    <div style="background-color: #f8f9fa; border: 1px solid #e9ecef; border-radius: 6px; padding: 15px; margin: 20px 0;">
      <table style="width: 100%; font-size: 13px; color: #333;" cellpadding="4">
        <tr>
          <td style="font-weight: bold; width: 35%;">Server Hostname:</td>
          <td>$DOMAIN</td>
        </tr>
        <tr>
          <td style="font-weight: bold;">Timestamp:</td>
          <td>$(date '+%d.%m.%Y %H:%M:%S')</td>
        </tr>
        <tr>
          <td style="font-weight: bold;">Operation Mode:</td>
          <td><span style="background: #e2e3e5; color: #383d41; padding: 2px 6px; border-radius: 4px; font-weight: bold;">TEST_MODE = $TEST_MODE</span></td>
        </tr>
      </table>
    </div>

    <div style="margin-top: 15px;">
      <strong style="color: #d9534f; font-size: 13px;">🔍 Captured Error Detail:</strong>
      <pre style="background-color: #272822; color: #f8f8f2; padding: 12px; border-radius: 6px; font-size: 11px; overflow-x: auto; white-space: pre-wrap; margin-top: 5px;">$ERROR_DETAILS</pre>
    </div>

    <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;">
    <p style="font-size: 11px; color: #888; margin: 0; text-align: center;">Zimbra Automated Server Management System</p>
  </div>
</div>
EOF

    rm -f "$ERR_LOG"
    exit 1
fi

rm -f "$ERR_LOG"

# ==============================================================================
# 2. CERTIFICATE PREPARATION & DEPLOYMENT
# ==============================================================================
WORKING_DIR="/tmp/zimbra_cert_prep"
mkdir -p "$WORKING_DIR"
rm -f "$WORKING_DIR"/*

wget -q -O "$WORKING_DIR/isrgrootx1.pem" https://letsencrypt.org/certs/isrgrootx1.pem
cat "/etc/letsencrypt/live/$DOMAIN/chain.pem" "$WORKING_DIR/isrgrootx1.pem" > "$WORKING_DIR/commercial_ca.crt"
cp -f "/etc/letsencrypt/live/$DOMAIN/cert.pem" "$WORKING_DIR/commercial.crt"

cp -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" /opt/zimbra/ssl/zimbra/commercial/commercial.key
chown zimbra:zimbra /opt/zimbra/ssl/zimbra/commercial/commercial.key
chown zimbra:zimbra "$WORKING_DIR"/*

# Verify Certificate Chain
su - zimbra -c "/opt/zimbra/bin/zmcertmgr verifycrt comm /opt/zimbra/ssl/zimbra/commercial/commercial.key $WORKING_DIR/commercial.crt $WORKING_DIR/commercial_ca.crt"

if [ $? -eq 0 ]; then
    echo "Certificate chain verified successfully."
    if [ "$TEST_MODE" = false ]; then
        echo "Deploying certificate to Zimbra..."
        su - zimbra -c "/opt/zimbra/bin/zmcertmgr deploycrt comm $WORKING_DIR/commercial.crt $WORKING_DIR/commercial_ca.crt"
    else
        echo "⚠️  TEST MODE: zmcertmgr deploycrt step skipped."
    fi
else
    echo "ERROR: Certificate verification failed!"
    rm -rf "$WORKING_DIR"
    exit 1
fi

# Nginx SNI and Multi-Domain Chain Update
cat "$WORKING_DIR/commercial.crt" "$WORKING_DIR/commercial_ca.crt" > /opt/zimbra/conf/nginx.crt
chown zimbra:zimbra /opt/zimbra/conf/nginx.crt
chmod 644 /opt/zimbra/conf/nginx.crt

for d in "${ADDITIONAL_DOMAINS[@]}"; do
    if [ -f "/opt/zimbra/conf/domaincerts/$d.crt" ] || [ -d "/opt/zimbra/conf/domaincerts" ]; then
        cp -f /opt/zimbra/conf/nginx.crt "/opt/zimbra/conf/domaincerts/$d.crt"
    fi
done
chown -R zimbra:zimbra /opt/zimbra/conf/domaincerts/

# Reset LDAP Certificate Attributes
for d in "${ADDITIONAL_DOMAINS[@]}"; do
    su - zimbra -c "zmprov -l md $d zimbraSSLCertificate '' 2>/dev/null"
    su - zimbra -c "zmprov -l md $d zimbraSSLPrivateKey '' 2>/dev/null"
done
su - zimbra -c "zmprov -l ms $DOMAIN zimbraSSLCertificate '' 2>/dev/null"
su - zimbra -c "zmprov -l ms $DOMAIN zimbraSSLPrivateKey '' 2>/dev/null"

# Proxy Configuration Generation
su - zimbra -c "/opt/zimbra/libexec/zmproxyconfgen"
rm -rf "$WORKING_DIR"

# ==============================================================================
# 3. SERVICE RESTART & NOTIFICATION EMAIL
# ==============================================================================
if [ "$TEST_MODE" = false ]; then
    echo "Restarting Zimbra services..."
    su - zimbra -c "/opt/zimbra/bin/zmcontrol restart"
else
    echo "⚠️  TEST MODE: Zimbra service restart (zmcontrol restart) skipped."
fi

# Read Certificate Expiration Date
CERT_EXPIRE=$(openssl x509 -enddate -noout -in /opt/zimbra/conf/nginx.crt | cut -d= -f2)
CERT_EXPIRE_FORMATTED=$(date -d "$CERT_EXPIRE" '+%d.%m.%Y %H:%M:%S' 2>/dev/null || echo "$CERT_EXPIRE")

# Send Success HTML Email Notification
"$SENDMAIL_BIN" -t <<EOF
To: $TO_EMAIL
From: Zimbra Security <zimbra@yourdomain.com>
Subject: =?UTF-8?B?$(echo -n "${SUBJECT_PREFIX}🔒 ZIMBRA : SSL Certificate Successfully Renewed" | base64 -w 0)?=
MIME-Version: 1.0
Content-Type: text/html; charset=UTF-8

<div style="font-family: Arial, sans-serif; background-color: #f4f6f9; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 8px; padding: 25px; border-left: 6px solid #28a745; box-shadow: 0 2px 5px rgba(0,0,0,0.05);">
    <h2 style="color: #28a745; margin-top: 0; font-size: 20px;">🔒 SSL Certificate Successfully Renewed ${SUBJECT_PREFIX}</h2>
    <p style="color: #444; font-size: 14px; line-height: 1.5;">
      Zimbra Mail Server Let's Encrypt SSL certificates have been successfully updated and applied to all domain chains.
    </p>
    
    <div style="background-color: #f8f9fa; border: 1px solid #e9ecef; border-radius: 6px; padding: 15px; margin: 20px 0;">
      <table style="width: 100%; font-size: 13px; color: #333;" cellpadding="4">
        <tr>
          <td style="font-weight: bold; width: 40%;">Server Hostname:</td>
          <td>$DOMAIN</td>
        </tr>
        <tr>
          <td style="font-weight: bold;">Affected Domains:</td>
          <td>${ADDITIONAL_DOMAINS[*]} $DOMAIN</td>
        </tr>
        <tr>
          <td style="font-weight: bold;">Operation Time:</td>
          <td>$(date '+%d.%m.%Y %H:%M:%S')</td>
        </tr>
        <tr>
          <td style="font-weight: bold; color: #28a745;">Certificate Expiry Date:</td>
          <td style="font-weight: bold; color: #28a745;">$CERT_EXPIRE_FORMATTED</td>
        </tr>
        <tr>
          <td style="font-weight: bold;">Operation Mode:</td>
          <td><span style="background: #e2e3e5; color: #383d41; padding: 2px 6px; border-radius: 4px; font-weight: bold;">TEST_MODE = $TEST_MODE</span></td>
        </tr>
      </table>
    </div>

    <div style="background-color: #e8f4fd; border-left: 4px solid #0288d1; padding: 12px; border-radius: 4px; font-size: 13px; color: #01579b;">
      <strong>ℹ️ Notice:</strong> Zimbra services (<code>zmcontrol restart</code>) were automatically restarted to activate the new certificate. Any service warning emails received during this window <b>are normal and expected</b>.
    </div>

    <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;">
    <p style="font-size: 11px; color: #888; margin: 0; text-align: center;">Zimbra Automated Server Management System</p>
  </div>
</div>
EOF

echo "Process completed successfully! (TEST_MODE=$TEST_MODE)"
