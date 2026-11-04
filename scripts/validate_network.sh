#!/bin/bash
# ==============================================================================
# OMNIA SYSTEM - WBS 2.4 Network & Infrastructure Validation Script
# ==============================================================================

# Modifica questi IP con gli IP reali delle tue VM Azure
TARGET_IP="10.0.1.10"
WAF_IP="10.0.1.20"
SIEM_IP="10.0.1.30"
SSH_USER="azureuser"
SSH_KEY="~/.ssh/id_rsa"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=================================================="
echo " Starting Network & Service Validation (WBS 2.4) "
echo "=================================================="

# 1. Test Connettività Ping / IP
echo -e "\n[1/4] Testing Basic Reachability (Ping)..."
for ip in $TARGET_IP $WAF_IP $SIEM_IP; do
    if ping -c 2 -W 3 $ip > /dev/null 2>&1; then
        echo -e "  [+] Node $ip is ${GREEN}REACHABLE${NC}"
    else
        echo -e "  [-] Node $ip is ${RED}UNREACHABLE${NC}"
    fi
done

# 2. Test Servizio Target (OWASP Juice Shop direct)
echo -e "\n[2/4] Testing Target Web Service (Juice Shop on port 3000)..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$TARGET_IP:3000)
if [ "$HTTP_STATUS" -eq 200 ]; then
    echo -e "  [+] Juice Shop on $TARGET_IP:3000 is ${GREEN}UP (HTTP 200)${NC}"
else
    echo -e "  [-] Juice Shop test failed with HTTP Status: ${RED}$HTTP_STATUS${NC}"
fi

# 3. Test Proxy WAF -> Target (Nginx + ModSecurity on port 80)
echo -e "\n[3/4] Testing WAF Proxy Flow (Reverse Proxy to Target)..."
WAF_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$WAF_IP)
if [ "$WAF_STATUS" -eq 200 ]; then
    echo -e "  [+] WAF Forwarding to Juice Shop is ${GREEN}WORKING (HTTP 200)${NC}"
else
    echo -e "  [-] WAF Proxy test failed with HTTP Status: ${RED}$WAF_STATUS${NC}"
fi

# 4. Test WAF Block (SQL Injection Simulation)
echo -e "\n[4/4] Testing WAF Security Rule (SQLi Block Test)..."
BLOCK_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$WAF_IP/rest/user/login?email='OR 1=1--")
if [ "$BLOCK_STATUS" -eq 403 ]; then
    echo -e "  [+] WAF ModSecurity Rule active: ${GREEN}BLOCKED (HTTP 403 Access Denied)${NC}"
else
    echo -e "  [-] WAF Rule test failed. Expected 403, got: ${RED}$BLOCK_STATUS${NC}"
fi

echo -e "\n=================================================="
echo " Validation Completed! "
echo "=================================================="