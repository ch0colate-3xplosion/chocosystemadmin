#!/bin/bash

# Function to log the date, time, and action
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SSH key generated for user $1" >> ssh_key_generation.log
}

# Prompt for username
read -p "Enter username: " username

# Prompt for password
read -sp "Enter password: " password
echo

# Create a directory based on the username
mkdir -p "$username"

# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "$username" -N "$password" -f ./$username/$username

# Log the action
log_action "$username"

echo "SSH key pair generated in directory '$username'"
echo "Log entry created."
