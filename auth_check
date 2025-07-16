#!/bin/bash
# print colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK") echo -e "${GREEN}[OK]${NC} $message" ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "INFO") echo -e "${BLUE}[INFO]${NC} $message" ;;
    esac
}

echo "SSH LISTENING PORTS"
echo "----------------------"
SSH_PORTS=$(netstat -tlnp 2>/dev/null | grep sshd | awk '{print $4}' | cut -d: -f2 | sort -n | uniq)
if [[ -n "$SSH_PORTS" ]]; then
    print_status "OK" "SSH is listening on ports: $(echo $SSH_PORTS | tr '\n' ' ')"
else
    print_status "ERROR" "No SSH ports found listening"
fi

echo ""

echo "AUTHORIZED SSH USERS"
echo "-----------------------"

# Check for users with SSH keys
print_status "INFO" "Users with SSH keys:"
for user_dir in /home/*; do
    if [[ -d "$user_dir" ]]; then
        username=$(basename "$user_dir")
        auth_keys="$user_dir/.ssh/authorized_keys"
        if [[ -f "$auth_keys" ]]; then
            key_count=$(wc -l < "$auth_keys")
            echo "  $username: $key_count key(s)"
        fi
    fi
done
# Check root authorized keys
if [[ -f "/root/.ssh/authorized_keys" ]]; then
    root_keys=$(wc -l < "/root/.ssh/authorized_keys")
    echo "  root: $root_keys key(s)"
fi

echo ""

echo "CURRENT SSH SESSIONS"
echo "-----------------------"
CURRENT_SESSIONS=$(who | grep -E "pts|tty" | wc -l)
if [[ $CURRENT_SESSIONS -gt 0 ]]; then
    print_status "INFO" "Current SSH sessions: $CURRENT_SESSIONS"
    who | grep -E "pts|tty"
else
    print_status "INFO" "No current SSH sessions"
fi

echo ""

echo "RECENT SSH CONNECTIONS"
echo "-------------------------"
if [[ -f "/var/log/auth.log" ]]; then
    print_status "INFO" "Recent successful SSH logins (last 20):"
    grep "sshd.*Accepted" /var/log/auth.log | tail -20 | while read line; do
        echo "  $line"
    done
    
    echo ""
    print_status "INFO" "Recent failed SSH attempts (last 10):"
    grep "sshd.*Failed" /var/log/auth.log | tail -10 | while read line; do
        echo "  $line"
    done
else
    print_status "WARN" "Auth log file not found"
fi

echo ""
