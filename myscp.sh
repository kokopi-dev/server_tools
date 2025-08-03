#!/bin/bash
imp() {
    local path=$1
    if [ -f "$path" ]; then
        set -a
        source $path
        set +a
    fi
}
imp ".env" #IP_ADDRESS, PORT, USERNAME, PRIVATE_KEY

validate_config() {
    if [[ -z "$IP_ADDRESS" ]]; then
        echo "Error: IP_ADDRESS not found in .env file!"
        exit 1
    fi
    
    echo "Using configuration:"
    echo "  IP Address: $IP_ADDRESS"
    [[ -n "$PORT" ]] && echo "  Port: $PORT"
    [[ -n "$USERNAME" ]] && echo "  Username: $USERNAME"
    [[ -n "$PRIVATE_KEY" ]] && echo "  Private Key: $PRIVATE_KEY"
    echo
}

# Function to build SCP command with optional parameters
build_scp_cmd() {
    local cmd="scp"
    
    # Add port if specified
    if [[ -n "$PORT" ]]; then
        cmd="$cmd -P $PORT"
    fi
    
    # Add private key if specified
    if [[ -n "$PRIVATE_KEY" ]] && [[ -f "$PRIVATE_KEY" ]]; then
        cmd="$cmd -i $PRIVATE_KEY"
    fi
    
    echo "$cmd"
}

# Function to build remote address
build_remote_address() {
    local remote_path="$1"
    local address=""
    
    # Add username if specified
    if [[ -n "$USERNAME" ]]; then
        address="$USERNAME@$IP_ADDRESS"
    else
        address="$IP_ADDRESS"
    fi
    
    # Add path
    if [[ -n "$remote_path" ]]; then
        address="$address:$remote_path"
    else
        address="$address:~/"
    fi
    
    echo "$address"
}

# Function to send files to remote server
send_file() {
    local local_file="$1"
    local remote_path="$2"
    
    if [[ -z "$local_file" ]]; then
        echo "Error: No local file specified!"
        return 1
    fi
    
    if [[ ! -f "$local_file" ]]; then
        echo "Error: Local file '$local_file' does not exist!"
        return 1
    fi
    
    local scp_cmd=$(build_scp_cmd)
    local remote_addr=$(build_remote_address "$remote_path")
    
    echo "Sending '$local_file' to '$remote_addr'..."
    $scp_cmd "$local_file" "$remote_addr"
    
    if [[ $? -eq 0 ]]; then
        echo "File sent successfully!"
    else
        echo "Error: Failed to send file!"
        return 1
    fi
}

# Function to retrieve files from remote server
retrieve_file() {
    local remote_file="$1"
    local local_path="$2"
    
    if [[ -z "$remote_file" ]]; then
        echo "Error: No remote file specified!"
        return 1
    fi
    
    # Default local path if not specified
    if [[ -z "$local_path" ]]; then
        local_path="./"
    fi
    
    local scp_cmd=$(build_scp_cmd)
    local remote_addr=$(build_remote_address "$remote_file")
    
    echo "Retrieving '$remote_file' from '$IP_ADDRESS' to '$local_path'..."
    $scp_cmd "$remote_addr" "$local_path"
    
    if [[ $? -eq 0 ]]; then
        echo "File retrieved successfully!"
    else
        echo "Error: Failed to retrieve file!"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [send|get] <file_path> [destination_path]"
    echo ""
    echo "Commands:"
    echo "  send <local_file> [remote_path]    Send file to remote server"
    echo "  get <remote_file> [local_path]     Retrieve file from remote server"
    echo ""
    echo "Examples:"
    echo "  $0 send myfile.txt                 # Send to remote home directory"
    echo "  $0 send myfile.txt /tmp/           # Send to remote /tmp/"
    echo "  $0 get /remote/file.txt            # Get file to current directory"
    echo "  $0 get /remote/file.txt ./downloads/ # Get file to ./downloads/"
    echo ""
    echo "Configuration loaded from .env file:"
    echo "  IP_ADDRESS (required)"
    echo "  PORT (optional)"
    echo "  USERNAME (optional)"
    echo "  PRIVATE_KEY (optional)"
}

main() {
    validate_config

    case "$1" in
        "send")
            if [[ $# -lt 2 ]]; then
                echo "Error: Missing file path for send operation!"
                show_usage
                exit 1
            fi
            send_file "$2" "$3"
            ;;
        "get")
            if [[ $# -lt 2 ]]; then
                echo "Error: Missing file path for get operation!"
                show_usage
                exit 1
            fi
            retrieve_file "$2" "$3"
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
