#!/bin/bash
# Configuration, Add API_TOKEN, ZONE_ID from cloudflare. Also edit DOMAINS hash
API_TOKEN=""
ZONE_ID=""
LAST_IP_FILE="/tmp/last_known_ip"
LAST_IP=$(cat "$LAST_IP_FILE" 2>/dev/null || echo "")

declare -A DOMAINS
# domain name: record_type,
DOMAINS["api.sample.com"]="A,"

if [ "$CURRENT_IP" == "$LAST_IP" ]; then
    # echo -e "IP Unchanged, skipping cloudflare update"
    exit 1
fi

# Get current public IP
CURRENT_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)

if ! [[ $CURRENT_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Error: Could not get valid IP address. Got: $CURRENT_IP"
    exit 1
fi

for name in "${!DOMAINS[@]}"; do
    IFS=',' read -ra values <<< "${DOMAINS[$name]}"
    #echo "${values[0]}" #record type
    #echo "$name" #record name
    local record_type="${values[0]}"
    local dns_response=$(http --json GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
	  Authorization:"Bearer $API_TOKEN" \
	  name=="$name" type=="$record_type")

    if ! echo "$dns_response" | jq -e '.success' > /dev/null; then
        echo "Error getting DNS records:"
        echo "$dns_response" | jq
    fi
    local current_dns_ip=$(echo "$dns_response" | jq -r '.result[0].content')
    local record_id=$(echo "$dns_response" | jq -r '.result[0].id')

    if [ "$CURRENT_IP" != "$current_dns_ip" ]; then
        echo "IP changed from $current_dns_ip to $CURRENT_IP. Updating DNS record..."

        local update_response=$(http --json PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
          Authorization:"Bearer $API_TOKEN" \
          content=="$CURRENT_IP" type=="$record_type" name=="$name" proxied=="true")

        if echo "$update_response" | jq -e '.success' > /dev/null; then
            echo "DNS record updated successfully!"
	    echo "$CURRENT_IP" > "$LAST_IP_FILE"
        else
            echo "Error updating DNS record:"
            echo "$update_response" | jq
        fi
    else
        echo "IP hasn't changed. Current IP: $CURRENT_IP"
    fi
done
