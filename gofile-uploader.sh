#!/bin/bash

# Check if curl, jq, and ping are installed
for cmd in curl jq ping; do
    if ! command -v $cmd &> /dev/null; then
        echo "ERROR: $cmd is not installed." && exit 1
    fi
done

# Exit if no file is specified
if [[ "$#" -eq 0 ]]; then
    echo -e 'ERROR: No File Specified!' && exit 1
fi

# File to upload
FILE="$1"

# Check if the file exists
if [[ ! -f "$FILE" ]]; then
    echo "ERROR: File does not exist!" && exit 1
fi

# Find the available servers to upload
SERVERS=$(curl -s https://api.gofile.io/servers)

# Debug: Print the servers response
echo "SERVERS RESPONSE: $SERVERS"

# Extract the list of server names
SERVER_NAMES=$(echo "$SERVERS" | jq -r '.data.servers[].name')

# Debug: Print all server names
echo "Available Servers: $SERVER_NAMES"

# Initialize variables for best server selection
BEST_SERVER=""
BEST_PING=100000  # Arbitrary high number for initialization

# Ping each server to find the one with the lowest latency
for SERVER in $SERVER_NAMES; do
    # Extract the server's IP address using ping
    PING_RESULT=$(ping -c 1 -W 1 ${SERVER}.gofile.io | grep 'time=' | awk -F'time=' '{ print $2 }' | awk '{ print $1 }')

    # Debug: Print the ping result for each server
    echo "Ping to $SERVER: ${PING_RESULT} ms"

    # If the ping is successful and lower than the current best, update the best server
    if [[ -n "$PING_RESULT" && $(echo "$PING_RESULT < $BEST_PING" | bc) -eq 1 ]]; then
        BEST_SERVER="$SERVER"
        BEST_PING="$PING_RESULT"
    fi
done

# Check if a best server was found
if [[ -z "$BEST_SERVER" ]]; then
    echo "ERROR: No reachable servers found." && exit 1
fi

# Debug: Print the best server
echo "Best Server: $BEST_SERVER with ping $BEST_PING ms"

# Upload the file to the best server
UPLOAD=$(curl -F "file=@${FILE}" https://${BEST_SERVER}.gofile.io/uploadFile)

# Debug: Print the upload response
echo "UPLOAD RESPONSE: $UPLOAD"

# Extract the download link
LINK=$(echo "$UPLOAD" | jq -r '.data.downloadPage')

# Check if the link was retrieved
if [[ -z "$LINK" ]]; then
    echo "ERROR: Failed to retrieve the download link." && exit 1
fi

# Print the link
echo "Download Link: $LINK"
echo " "
