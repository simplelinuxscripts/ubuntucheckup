#!/bin/bash

###########################################
#
# Update all Ubuntu packages (snap and apt)
#
###########################################

export LC_ALL=en_US.UTF-8

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD="\033[1m"
NC=$'\E[0m'

print_success() {
    success_str="$1"
    echo
    echo -e "${GREEN}OK!${NC} ${success_str}"
    echo
}

print_warning() {
    warning_str="$1"
    echo
    echo -e "${YELLOW}Warning:${NC} ${warning_str}"
    echo
}

print_error() {
    error_str="$1"
    echo
    echo -e "${RED}ERROR:${NC} ${error_str}"
    echo
}

echo
echo -e "${BOLD}********************${NC}"
echo -e "${BOLD}UPDATE ALL PACKAGES...${NC}"
echo -e "${BOLD}********************${NC}"

echo
read -p "Close all apps and press Enter to continue..."

if snap list firefox &>/dev/null; then
    pkill -f firefox 2> /dev/null
fi
if snap list chromium &>/dev/null; then
    pkill -f chromium 2> /dev/null
fi

ping -c 1 -W 5 "www.google.com" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    print_error "no network connection detected. Connect to internet and rerun the script."
    read -p "Press Enter to exit..."
    exit 1
fi

echo
echo -e "${BOLD}***** sudo snap refresh... *****${NC}"
echo
sudo snap refresh
if [ $? -ne 0 ]; then
    print_error "sudo snap refresh failed"
    read -p "Press Enter to exit..."
    exit 1
fi

snap_packages_that_can_be_updated=$(sudo snap refresh --list 2>&1 | grep -v "All snaps up to date")
# example:
#   sudo snap refresh --list
#   Name      Version         Rev   Size   Publisher   Notes
#   chromium  133.0.6943.141  3051  185MB  canonical✓  -
if [ -n "${snap_packages_that_can_be_updated}" ]; then
    echo "${snap_packages_that_can_be_updated}" | awk -v yellow="$YELLOW" -v reset="$NC" 'NR==1 {print; next} {print yellow $1 reset, substr($0, length($1)+2)}'
    print_error "sudo snap refresh did not update all snap packages (see above)"
    read -p "Press Enter to exit..."
    exit 1
fi

echo
echo -e "${BOLD}***** sudo apt update... *****${NC}"
echo
sudo apt update
if [ $? -ne 0 ]; then
    print_error "sudo apt update failed"
    read -p "Press Enter to exit..."
    exit 1
fi

sleep 3
echo
echo -e "${BOLD}***** sudo apt -y upgrade... *****${NC}"
echo
sudo apt -y upgrade
if [ $? -ne 0 ]; then
    print_error "sudo apt -y upgrade"
    read -p "Press Enter to exit..."
    exit 1
fi

echo
echo -e "${BOLD}***** final status: *****${NC}"
echo
sudo apt-get check
if [ $? -eq 0 ]; then
    print_success "SUCCESS"
else
    print_error "sudo apt-get check"
fi
read -p "Press Enter to exit..."
