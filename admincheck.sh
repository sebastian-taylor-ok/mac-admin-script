#!/bin/bash

# Define the expected admin user
EXPECTED_ADMIN_USER="oktanaadmin"

# Ensure the correct PATH is set
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"

#Clear terminal
clear

echo
echo "-------------------------------------------"
echo "Running Admin Privilege Check and Cleanup..."
echo "-------------------------------------------"
echo

# Function to check if the expected admin user exists
check_admin_user() {
    id "$EXPECTED_ADMIN_USER" &> /dev/null
    return $?
}

# Verify the expected admin user exists
if ! check_admin_user; then
    echo "!!-------------------------------------------!!"
    echo "❌ The expected admin user ($EXPECTED_ADMIN_USER) does not exist! Exiting to avoid lockout."
    echo "!!-------------------------------------------!!"
    exit 1
fi

# Function to check if a user is an admin
is_admin_user() {
    dscl . -read /Groups/admin GroupMembership | grep -q "$1"
    return $?
}

# Function to check if a user is a mobile account
is_mobile_account() {
    dscl . -read "/Users/$1" OriginalNodeName &> /dev/null
    return $?
}

# Check if the expected admin user has admin rights
if ! is_admin_user "$EXPECTED_ADMIN_USER"; then
    echo "!!-------------------------------------------!!"
    echo "❌ $EXPECTED_ADMIN_USER does NOT have admin privileges! Exiting to avoid lockout."
    echo "!!-------------------------------------------!!"
    exit 1
fi

# Check if the expected admin user is a mobile account
if ! is_mobile_account "$EXPECTED_ADMIN_USER"; then
    echo "!!-------------------------------------------!!"
    echo "❌ $EXPECTED_ADMIN_USER is NOT a mobile account! Exiting to avoid lockout."
    echo "!!-------------------------------------------!!"
    exit 1
fi

echo "-------------------------------------------"
echo "✅ $EXPECTED_ADMIN_USER has admin privileges and is a mobile account."
echo "-------------------------------------------"


# Switch to the admin user to perform privileged actions
echo "Switching to $EXPECTED_ADMIN_USER to perform privileged actions..."

su - "$EXPECTED_ADMIN_USER" -c '
    # Disable the root account if enabled
    echo "-------------------------------------------"
    echo "Disabling the root account..."
    if dsenableroot -d &> /dev/null; then
        echo "✅ Root account has been disabled."
        echo "-------------------------------------------"
    else
        echo "ℹ️ Root account was already disabled."
        echo "-------------------------------------------"
    fi

    # Find other admin users (excluding root and the expected admin user)
    OTHER_ADMINS=$(dscl . -read /Groups/admin GroupMembership | tr " " "\n" | grep -Ev "^(GroupMembership:|root|'"$EXPECTED_ADMIN_USER"')$")

    if [ -n "$OTHER_ADMINS" ]; then
        echo "-------------------------------------------"
        echo "⚠️ The following users have admin privileges and will be removed from the admin group:"
        echo "$OTHER_ADMINS"
        echo "-------------------------------------------"

        for user in $OTHER_ADMINS; do
            echo "-------------------------------------------"
            echo "Removing admin privileges from $user..."
            sudo /usr/sbin/dseditgroup -o edit -d "$user" -t user admin
            echo "✅ Admin privileges removed from $user."
            echo "-------------------------------------------"
        done
    else
        echo "✅ No unauthorized users have admin privileges."
        echo "-------------------------------------------"
    fi
'

echo "-------------------------------------------"
echo "✅ Script completed successfully."
echo "-------------------------------------------"
exit 0
