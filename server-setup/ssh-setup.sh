#!/bin/bash
# 1st arg: PORT number
SSHD_CONFIG="/etc/ssh/sshd_config"

PORT=$1

if [ -z $PORT ]; then
	echo -e "PORT number is required."
	exit 1
fi

update_ssh_config() {
    local option="$1"
    local value="$2"

    if grep -q "^#*\s*$option" "$SSHD_CONFIG"; then
        # Option exists, update it
        sed -i "s/^#*\s*$option.*/$option $value/" "$SSHD_CONFIG"
        echo "Updated: $option $value"
    else
        # Option doesn't exist, add it
        echo "$option $value" >> "$SSHD_CONFIG"
        echo "Added: $option $value"
    fi
}

update_ssh_config "Port" "$PORT"
update_ssh_config "PermitRootLogin" "no"
update_ssh_config "PubkeyAuthentication" "yes"
update_ssh_config "PasswordAuthentication" "no"

if sshd -t; then
	echo "✓ SSH configuration syntax is valid"
else
	echo "✗ SSH configuration has syntax errors!"
fi

echo "Setting up ufw"

ufw default deny incoming
ufw default allow outgoing

ufw allow "$PORT"/tcp comment "SSH"

ufw show added

ufw enable
ufw status verbose

echo -e "Run `sudo systemctl enable ssh`, `restart`, and `status` + validate that Port is correct"
