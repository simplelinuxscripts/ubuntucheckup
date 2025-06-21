#!/bin/bash

############################
#
# Ubuntu packages update script
#
############################

export LC_ALL=en_US.UTF-8

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD=$'\E[1m'
NC=$'\E[0m'

print_success() {
    success_str="$1"
    echo -e "${GREEN}CHECKED${NC} ${success_str}"
}

print_warning() {
    warning_str="$1"
    echo -e "${YELLOW}Warning:${NC} ${warning_str}"
}

print_error() {
    error_str="$1"
    echo -e "${RED}ERROR:${NC} ${error_str}"
}

ping -c 1 -W 5 "www.google.com" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    print_error "no network connection detected. Connect to internet and rerun the script."
    echo
    exit 1
fi

# Check if snap packages
echo "Checking snap packages..."
echo "snap refresh times:"
snap refresh --time | sed "/yesterday/s/.*/${BOLD}&${NC}/" | sed "/today/s/.*/${BOLD}&${NC}/" | sed "/tomorrow/s/.*/${BOLD}&${NC}/" | sed 's/^/  /'
snap_packages_that_can_be_updated=$(sudo snap refresh --list 2>&1 | grep -v "All snaps up to date")
# example:
#   sudo snap refresh --list
#   Name      Version         Rev   Size   Publisher   Notes
#   chromium  133.0.6943.141  3051  185MB  canonical✓  -
if [ -n "${snap_packages_that_can_be_updated}" ]; then
    echo "${snap_packages_that_can_be_updated}"
    print_warning "above snap packages could be updated manually instead of automatically by default ('sudo snap refresh' to be run after having closed the applications, then 'snap refresh --list' for check)"
else
    print_success "snap packages are up-to-date"
fi
read -p "Press Enter to continue..."
echo

# Check logs of last unattended-upgrades automatic runs
echo "Checking unattended-upgrades..."
echo "timers:"
systemctl list-timers apt-daily.timer apt-daily-upgrade.timer | head -n 3
echo "updates allowed to be applied automatically by unattended-upgrades: (Note: \"apt\" will detect wider set of updates)"
less /var/log/unattended-upgrades/unattended-upgrades.log | tail -35 | sed "/ERROR/s/.*/${BOLD}&${NC}/" | sed "/INFO No packages found/s/.*/${BOLD}&${NC}/" | sed "/INFO All upgrades installed/s/.*/${BOLD}&${NC}/" | sed 's/^/  /'
read -p "Press Enter to continue..."
echo

# Manual updates
echo "Running apt update..."
sudo apt update
if [ $? -ne 0 ]; then
    # detect errors like GPG key errors, hash sum mismatches...
    print_error "apt update failed"
    echo
    exit 1
fi

echo
read -p "Press Enter to check available upgrades..."
echo

echo "Packages to upgrade:"
apt list --upgradable

# See https://www.baeldung.com/linux/find-security-updates-list: sudo unattended-upgrade --dry-run 2>&1 would be more accurate but can be much slower => apt is preferred
nb_security_updates=$(apt list --upgradable 2>&1 | grep -i "security" | wc -l)
if [ "$nb_security_updates" -ne 0 ]; then
    echo -e "${BOLD}among which security update(s)${NC}"
else
    echo "among which no security updates"
fi

echo
read -p "Press Enter to start upgrades..."
echo

echo "Running apt upgrade..."
sudo apt upgrade
if [ $? -ne 0 ]; then
    print_error "apt upgrade failed"
    echo
    exit 1
fi

sudo apt-get check
if [ $? -eq 0 ]; then
    print_success "apt-get check"
else
    print_error "apt-get check"
fi
