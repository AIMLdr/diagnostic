#!/bin/bash

#################################
# mailman.sh - Mail Setup Script
# Author: Your Name
# Date: YYYY-MM-DD
#################################

# Function to print messages in color
print_message() {
    local type="$1"
    local message="$2"
    case "$type" in
        "info")
            echo -e "\e[34m[INFO]\e[0m $message"
            ;;
        "success")
            echo -e "\e[32m[SUCCESS]\e[0m $message"
            ;;
        "warning")
            echo -e "\e[33m[WARNING]\e[0m $message"
            ;;
        "error")
            echo -e "\e[31m[ERROR]\e[0m $message"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Function to check if the script is run as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_message "error" "Please run this script as root or using sudo."
        exit 1
    fi
}

# Function to install mailutils and postfix
install_mail_packages() {
    print_message "info" "Updating package lists..."
    apt update -y

    print_message "info" "Installing mailutils and postfix..."
    
    # Preconfigure postfix to avoid interactive prompts
    echo "postfix postfix/main_mailer_type string 'Local only'" | debconf-set-selections
    echo "postfix postfix/mailname string localhost" | debconf-set-selections
    
    apt install mailutils postfix -y

    if [ $? -ne 0 ]; then
        print_message "error" "Failed to install mailutils and postfix."
        exit 1
    fi

    print_message "success" "Successfully installed mailutils and postfix."
}

# Function to configure postfix
configure_postfix() {
    print_message "info" "Configuring postfix for 'Local only' mail delivery..."

    # Ensure postfix is set to 'Local only'
    postconf -e "mydestination = localhost.localdomain, localhost"

    # Restart postfix to apply changes
    systemctl restart postfix

    if [ $? -ne 0 ]; then
        print_message "error" "Failed to restart postfix."
        exit 1
    fi

    print_message "success" "Postfix configured successfully."
}

# Function to create a dedicated mail user
create_mail_user() {
    read -p "Enter the username for the dedicated mail user [draiml]: " mail_user
    mail_user=${mail_user:-draiml}

    # Check if user already exists
    if id "$mail_user" &>/dev/null; then
        print_message "warning" "User '$mail_user' already exists. Skipping user creation."
    else
        print_message "info" "Creating dedicated mail user '$mail_user'..."
        adduser --disabled-login "$mail_user"

        if [ $? -ne 0 ]; then
            print_message "error" "Failed to create user '$mail_user'."
            exit 1
        fi

        print_message "success" "User '$mail_user' created successfully."
    fi
}

# Function to set up sendmail aliases
setup_sendmail_aliases() {
    read -p "Enter the destination email address for sending alerts [your_email@example.com]: " destination_email
    destination_email=${destination_email:-your_email@example.com}

    print_message "info" "Setting up sendmail aliases..."

    # Backup existing aliases file
    cp /etc/aliases /etc/aliases.backup.$(date +%F_%T)

    # Add or update the alias for the dedicated mail user
    if grep -q "^$mail_user:" /etc/aliases; then
        sed -i "s/^$mail_user:.*/$mail_user: $destination_email/" /etc/aliases
    else
        echo "$mail_user: $destination_email" >> /etc/aliases
    fi

    # Update the aliases database
    newaliases

    if [ $? -ne 0 ]; then
        print_message "error" "Failed to update sendmail aliases."
        exit 1
    fi

    print_message "success" "Sendmail aliases configured successfully."
}

# Function to test email sending
test_email() {
    print_message "info" "Sending a test email from 'draiml@localhost' to '$destination_email'..."

    echo "This is a test email from draiml@localhost." | mail -s "Test Email from draiml@localhost" "$mail_user@localhost"

    # Optional: Check if email was sent successfully
    if [ $? -ne 0 ]; then
        print_message "error" "Failed to send test email."
        exit 1
    fi

    print_message "success" "Test email sent successfully. Please check your inbox at '$destination_email'."
}

# Function to display completion message
completion_message() {
    print_message "success" "Mail setup completed successfully!"
    echo "-----------------------------------------------------------------"
    echo "Mail is configured to send alerts from 'draiml@localhost' to '$destination_email'."
    echo "You can now proceed to set up Llamalert or other monitoring tools."
    echo "-----------------------------------------------------------------"
}

# Main Execution Flow
main() {
    check_root
    install_mail_packages
    configure_postfix
    create_mail_user
    setup_sendmail_aliases
    test_email
    completion_message
}

# Run the main function
main
