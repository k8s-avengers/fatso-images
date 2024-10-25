#!/usr/bin/env bash

# Function to create a user for Ansible AWX with SSH key setup
function mkosi_script_postinst_chroot::add_ansible_user() {
    local USERNAME="ansible"
    local SSH_DIR="/home/$USERNAME/.ssh"
    local AUTHORIZED_KEYS_FILE="$SSH_DIR/authorized_keys"

    # Detect OS type
    if [ -f /etc/debian_version ]; then
        log info "Debian/Ubuntu detected"
        # Create ansible user
        adduser --comment "" --disabled-password --quiet "$USERNAME"
        # Add to sudo group
        usermod -aG sudo "$USERNAME"
    elif [ -f /etc/redhat-release ]; then
        log info "RHEL/Fedora/Rocky detected"
        # Create ansible user (non-interactive)
        adduser "$USERNAME"
        # Add to wheel group
        usermod -aG wheel "$USERNAME"
    else
        log info "Unsupported distribution"
        exit 1
    fi

    # Create .ssh directory
    log info "Creating SSH directory: $SSH_DIR"
    mkdir -p "$SSH_DIR"
    chown "$USERNAME:$USERNAME" "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    # Add a SSH key to authorized_keys
    log info "Adding SSH key for user $USERNAME"
    # The user creation has been tested on different vendor flavors, successfully by connecting using ssh to the machines using a key pair.
    #A fake key string is being added in the code for convenience. In a case in the future that is intended to use a working key, 
    #replace this string here with a working pub key.
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAakefakefakefakefake...fake" > "$AUTHORIZED_KEYS_FILE"
    chown "$USERNAME:$USERNAME" "$AUTHORIZED_KEYS_FILE"
    chmod 600 "$AUTHORIZED_KEYS_FILE"

    # Setup sudo access without password
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
    chmod 440 /etc/sudoers.d/ansible

    log info "User $USERNAME set up successfully with SSH key"
}