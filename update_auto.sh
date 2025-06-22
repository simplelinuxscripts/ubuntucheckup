#!/bin/bash

#########################################
#
# Ubuntu packages automatic update script
#
#########################################

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
echo -e "${BOLD}AUTOMATIC UPDATES...${NC}"
echo -e "${BOLD}********************${NC}"

echo
read -p "Press Enter to continue..."

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

echo
echo -e "${BOLD}***** sudo apt update... *****${NC}"
echo
sudo apt update
if [ $? -ne 0 ]; then
    print_error "sudo apt update failed"
    read -p "Press Enter to exit..."
    exit 1
fi

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
    print_success "success"
else
    print_error "sudo apt-get check"
fi
read -p "Press Enter to exit..."
