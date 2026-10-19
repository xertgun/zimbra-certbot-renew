# 🔒 Zimbra Certbot SSL Renewal & Deployment Script

An automated Bash-based utility to renew Let's Encrypt SSL certificates, verify chains, deploy commercial certificates to Zimbra ZCS, update multi-domain SNI bindings, and dispatch responsive HTML email reports.

> 📌 **Tested & Compatible with:** Zimbra Collaboration Suite 8.8.15 (ZCS 8.8.15 GA) & Certbot.

## ✨ Features

- **Safe Test Mode (`TEST_MODE`):** Allows dry-runs without consuming Let's Encrypt rate limits or restarting mail services during testing.
- **Privilege Validation:** Automatically aborts and sends an HTML alert if run without `root` privileges.
- **Let's Encrypt & ISRG Root Integration:** Automatically fetches and bundles intermediate/root certificates (`isrgrootx1.pem`) for complete chain trust.
- **Zimbra Certificate Deployment:** Verifies via `zmcertmgr` and deploys seamlessly.
- **Multi-Domain & SNI Support:** Updates Nginx default certificates and virtual host domain certs automatically.
- **HTML Email Notifications:** Sends detailed success or failure reports complete with exact timestamps, expiration dates, and error logs.

---

## 🚀 Quick Start

1. Create the system directory and download the script:
  ```bash
  sudo mkdir -p /opt/zimbra-renew && cd /opt/zimbra-renew
  wget https://raw.githubusercontent.com/xertgun/zimbra-certbot-renew/main/zimbra-renew.sh
  chmod +x zimbra-renew.sh
  ```

2. Edit the configuration parameters inside `zimbra-renew.sh`:
  ```text
  # Set to false for production live renewals
  TEST_MODE=true
  
  TO_EMAIL="admin@yourdomain.com"
  DOMAIN="mail.yourdomain.com"
  ADDITIONAL_DOMAINS=("yourdomain.com" "secondarydomain.com")
  ```

3. Test the script first in dry-run mode:
  ```bash
  sudo ./zimbra-renew.sh
  ```

4. Once verified, set `TEST_MODE=false` in the script and add it to your root crontab (`sudo crontab -e`) to automate renewals:
  ```cron
  0 3 1 * * /opt/zimbra-renew/zimbra-renew.sh >/dev/null 2>&1
  ```

## 💡 Why This Script Exists
Standard Certbot renewal hooks often fail on Zimbra because Zimbra requires a very specific certificate bundle structure (`commercial.crt`, `commercial_ca.crt`, and `commercial.key`), proper ownership permissions (`zimbra:zimbra`), Nginx SNI updates, LDAP attribute resets, and proxy configuration generation (`zmproxyconfgen`).

This script automates the entire end-to-end lifecycle safely while notifying administrators instantly via HTML emails if any step fails.

## 🔗 Related Projects
- [zimbra-security-check](https://github.com/xertgun/zimbra-security-check): Daily integrity scanner & automated incident reporter for Zimbra.
- [zimbra-fail2ban](https://github.com/xertgun/zimbra-fail2ban) - Fail2Ban filters, jail rules, and daily HTML defense reporter for Zimbra.
