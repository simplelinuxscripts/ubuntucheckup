#!/bin/bash

############################
#
# Linux bash script to check safety and health of Ubuntu installation (~ "Ubuntu antivirus")
#
############################

export LC_ALL=en_US.UTF-8

############
# Parameters
############

STOP_ON_WARNINGS=0
STOP_ON_ERRORS=0
TEST_SUDO_PWD=1

# Example of output of lsblk command:
# NAME                        MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINTS
# loop0                         7:0    0  74.2M  1 loop  /snap/core22/1380
# loop1                         7:1    0     4K  1 loop  /snap/bare/5
# loop2                         7:2    0 269.6M  1 loop  /snap/firefox/4173
# ...
# loop16                        7:16   0  10.7M  1 loop  /snap/snap-store/1218
# nvme0n1                     259:0    0 476.9G  0 disk
# ├─nvme0n1p1                 259:1    0     1G  0 part  /boot/efi
# ├─nvme0n1p2                 259:2    0     2G  0 part  /boot
# └─nvme0n1p3                 259:3    0 473.9G  0 part
#  └─dm_crypt-0              252:0    0 473.9G  0 crypt
#    └─ubuntu--vg-ubuntu--lv 252:1    0 473.9G  0 lvm    /
# => disk device for root folder is nvme0n1 => HARD_DISK_DEVICE set to "/dev/nvme0n1"
HARD_DISK_DEVICE="/dev/nvme0n1"

# Firefox snap settings folder
SNAP_FOLDER="${HOME}/snap"
SNAP_FIREFOX_FOLDER="${SNAP_FOLDER}/firefox/common/.mozilla/firefox"
SNAP_FIREFOX_PROFILE_FOLDER="${SNAP_FIREFOX_FOLDER}/mnu864hu.default"

# Chromimum snap settings folder
SNAP_CHROMIUM_FOLDER="${SNAP_FOLDER}/chromium/common/chromium/Default"

# Expected PATH environment variable value (any change of PATH environment variable will be detected)
EXPECTED_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:${HOME}/DOCUMENTS/Informatique/Programmes/Linux:${HOME}/DOCUMENTS/Informatique/Programmes/Linux/simplelinuxscripts/findlines:${HOME}/DOCUMENTS/Informatique/Programmes/Linux/simplelinuxscripts/ubuntucheckup"

# Optional: folder used to save a copy of some important configuration files
#           and therefore be able to regularly check that they were not modified
SCRIPT_FOLDER=$(dirname "$0")
CHECKUP_FOLDER="${SCRIPT_FOLDER}/checkup_files"

########
# Script
########

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_success() {
    success_str="$1"
    echo -e "${GREEN}CHECKED${NC} ${success_str}"
}

print_info() {
    info_str="$1"
    echo "Info: ${info_str}"
}

nb_warnings=0
print_warning() {
    warning_str="$1"
    nb_warnings=$((nb_warnings+1))
    echo -e "${YELLOW}Warning:${NC} ${warning_str}"
    if [ ${STOP_ON_WARNINGS} -eq 1 ]; then
        read -p "Press Enter to ignore..."
    fi
}

nb_errors=0
print_error() {
    error_str="$1"
    nb_errors=$((nb_errors+1))
    echo -e "${RED}ERROR:${NC} ${error_str}"
    if [ ${STOP_ON_ERRORS} -eq 1 ]; then
        read -p "Press Enter to ignore..."
    fi
}

if ! [ -d "${CHECKUP_FOLDER}" ]; then
    echo
    print_warning "checkup folder ${CHECKUP_FOLDER} does not exist."
    echo "Create it to fully benefit from the potential of this script."
    echo "This folder contains files and command results. They shall be saved manually by the user, as defined in this script."
    echo "They will then be checked for changes at each script execution, ensuring nothing critical has changed in the safety"
    echo "and health of the Ubuntu installation."
fi

echo
echo "---------- Check account ----------"
echo

# Check that password is requested for sudo commands
if [ ${TEST_SUDO_PWD} -eq 1 ]; then
    sudo -k
    sudo -n true 2> /dev/null
    if [ $? -eq 0 ]; then
        print_error "sudo without password"
    else
        print_success "sudo password"
    fi
else
    print_warning "sudo password check skipped"
fi

echo
echo "---------- Check network connections ----------"
echo

ping -c 1 -W 5 "www.google.com" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_success "network connection available"
else
    print_error "no network connection detected"
fi

wireless_sw_status=$(rfkill list)
if ! $(echo "${wireless_sw_status}" | grep -q "Soft blocked: no"); then
    print_success "wireless connections disabled"
else
    echo "${wireless_sw_status}"
    print_warning "wireless connection(s) enabled"
fi

echo
echo "---------- Check firewall ----------"
echo

ufw_status=$(sudo ufw status verbose)

ufw_status_1=$(echo "${ufw_status}" | grep -o "Status: active")
if [ "$ufw_status_1" == "Status: active" ]; then
    print_success "ufw enabled"
else
    print_error "ufw disabled ('sudo ufw enable' to be run)"
fi

ufw_status_2=$(echo "${ufw_status}" | grep -o "deny (incoming)")
if [ "$ufw_status_2" == "deny (incoming)" ]; then
    print_success "ufw incoming traffic denied"
else
    print_error "ufw incoming traffic is not denied"
fi

ufw_status_3=$(echo "${ufw_status}" | grep -o "allow (outgoing)")
if [ "$ufw_status_3" == "allow (outgoing)" ]; then
    print_success "ufw outgoing traffic allowed"
else
    print_error "ufw outgoing traffic is not allowed"
fi

ufw_status_4=$(echo "${ufw_status}" | grep -o "disabled (routed)")
if [ "$ufw_status_4" == "disabled (routed)" ]; then
    print_success "ufw routed traffic disabled"
else
    print_error "ufw routed traffic is not disabled"
fi

ufw_status_5=$(echo "${ufw_status}" |  grep -o "Logging: on (low)")
if [ "$ufw_status_5" == "Logging: on (low)" ]; then
    print_success "ufw logging on low"
else
    print_warning "ufw logging is not on+low"
fi

echo
echo "---------- Check apparmor ----------"
echo

error_found=0
apparmor_status=$(sudo systemctl status apparmor)
apparmor_loaded=$(echo "$apparmor_status" | grep "Loaded: loaded (/usr/lib/systemd/system/apparmor.service; enabled; preset: enabled)")
apparmor_active=$(echo "$apparmor_status" | grep "Active: active (exited)")
nb_apparmor_enforce_profiles=$(sudo aa-status | grep "profiles are in enforce mode" | grep -o '^[0-9]\+')
nb_apparmor_processes=$(sudo aa-status | grep "processes have profiles defined" | grep -o '^[0-9]\+')
nb_apparmor_enforce_processes=$(sudo aa-status | grep "processes are in enforce mode" | grep -o '^[0-9]\+')
nb_apparmor_prompt_processes=$(sudo aa-status | grep "processes are in prompt mode" | grep -o '^[0-9]\+')
nb_apparmor_unconfined_processes=$(sudo aa-status | grep "processes are unconfined" | grep -o '^[0-9]\+')
nb_apparmor_mixed_processes=$(sudo aa-status | grep "processes are in mixed mode" | grep -o '^[0-9]\+')
# Check that apparmor is on
if [ -z "${apparmor_loaded}" ]; then
    print_error "apparmor not loaded and enabled"
    error_found=1
elif [ -z "${apparmor_active}" ]; then
    print_error "apparmor not active"
    error_found=1
# Check total number of apparmor [enforce] profiles and processes
elif [ "${nb_apparmor_enforce_profiles}" == "" ] || [ ${nb_apparmor_enforce_profiles} -lt 50 ]; then # (adapt threshold value in this condition as needed)
  print_error "too few apparmor profiles in enforce mode (${nb_apparmor_enforce_profiles})"
  error_found=1
elif [ "${nb_apparmor_processes}" == "" ] || [ ${nb_apparmor_processes} -lt 5 ]; then # (adapt threshold value in this condition as needed)
  print_error "too few apparmor processes (${nb_apparmor_processes})"
  error_found=1
elif [ "${nb_apparmor_enforce_processes}" == "" ] || [ ${nb_apparmor_enforce_processes} -eq 0 ]; then
  print_error "no apparmor processes in enforce mode"
  error_found=1
else
  enforce_ratio=$((100 * nb_apparmor_enforce_processes / nb_apparmor_processes))
  if [ ${enforce_ratio} -lt 80 ]; then # (adapt threshold value in this condition as needed)
    print_error "too few apparmor processes in enforce mode (${nb_apparmor_enforce_processes} out of ${nb_apparmor_processes}: ${enforce_ratio}%)"
    error_found=1
  fi
fi
# Check unsafe apparmor processes 1/2
if [ "${nb_apparmor_prompt_processes}" == "" ] || [ ${nb_apparmor_prompt_processes} -ne 0 ]; then
  print_warning "apparmor processes in prompt mode (${nb_apparmor_prompt_processes})"
fi
if [ "${nb_apparmor_unconfined_processes}" == "" ] || [ ${nb_apparmor_unconfined_processes} -ne 0 ]; then
  print_warning "apparmor processes in unconfined mode (${nb_apparmor_unconfined_processes})"
fi
if [ "${nb_apparmor_mixed_processes}" == "" ] || [ ${nb_apparmor_mixed_processes} -ne 0 ]; then
  print_warning "apparmor processes in mixed mode (${nb_apparmor_mixed_processes})"
fi
# Check unsafe apparmor processes 2/2: complain mode
if [ -f "${CHECKUP_FOLDER}/apparmor_complain_processes_sauv.txt" ]; then
    nb_processes_in_complain_mode_sauv=$(more "${CHECKUP_FOLDER}/apparmor_complain_processes_sauv.txt" | grep "in complain mode" | awk '{print $1}')
    sudo aa-status | sed -n '/processes are in complain mode/,/processes are/p' | sed 's/([0-9]\+)/X/g' | sed '$d' > "${CHECKUP_FOLDER}/apparmor_complain_processes_current.txt"
    nb_processes_in_complain_mode_current=$(more "${CHECKUP_FOLDER}/apparmor_complain_processes_current.txt" | grep "in complain mode" | awk '{print $1}')
    if [[ "$nb_processes_in_complain_mode_sauv" =~ ^[0-9]+$ && "$nb_processes_in_complain_mode_current" =~ ^[0-9]+$ ]]; then
        if [ $nb_processes_in_complain_mode_sauv -lt $((nb_processes_in_complain_mode_current - 3)) ]; then
            diff "${CHECKUP_FOLDER}/apparmor_complain_processes_sauv.txt" "${CHECKUP_FOLDER}/apparmor_complain_processes_current.txt"
            if [ $? -ne 0 ]; then
                print_warning "apparmor processes in complain mode have changed (check changes and copy file ${CHECKUP_FOLDER}/apparmor_complain_processes_current.txt to ${CHECKUP_FOLDER}/apparmor_complain_processes_sauv.txt)"
            fi
        fi
    else
        print_warning "apparmor processes in complain mode check is skipped because numbers of processes cannot be extracted: $nb_processes_in_complain_mode_sauv, $nb_processes_in_complain_mode_current"
    fi
else
    print_warning "apparmor processes in complain mode check is skipped because reference file ${CHECKUP_FOLDER}/apparmor_complain_processes_sauv.txt does not exist"
fi

if [ ${error_found} -eq 0 ]; then
    print_success "apparmor"
fi

echo
echo "---------- Check disk ----------"
echo

if ! $(lsblk -o NAME,KNAME,FSTYPE,TYPE,MOUNTPOINT,SIZE | grep -q "crypt"); then
    print_warning "no disk is encrypted"
fi

disk_status=$(sudo smartctl -a "${HARD_DISK_DEVICE}")
if echo "${disk_status}" | grep -i -E 'FAIL|error|Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable|Bad|Uncorrectable|Unable' | grep -v "Media and Data Integrity Errors:    0" | grep -v "Error Information" | grep -v "No Errors Logged"; then
    print_error "disk errors detected, see above"
elif ! $(echo "${disk_status}" | grep -q "SMART overall-health self-assessment test result: PASSED"); then
    print_error "disk errors detected (test result)"
elif ! $(echo "${disk_status}" | grep -q "No Errors Logged"); then
    print_error "disk errors detected (errors logged)"
elif ! $(echo "${disk_status}" | grep -q "Critical Warning:                   0x00"); then
    print_error "disk errors detected (critical warnings)"
elif ! $(echo "${disk_status}" | grep -q "Media and Data Integrity Errors:    0"); then
    print_error "disk errors detected (media and data integrity)"
else
    print_success "disk health"
fi

echo
echo "---------- Check sessions ----------"
echo

# Check that ubuntu wayland session is available (safer than X11 and Xorg)
ubuntu_wayland_sessions=$(ls /usr/share/wayland-sessions/ | grep -E "ubuntu.*\.desktop") # example of ls /usr/share/wayland-sessions/ output: plasma.desktop  ubuntu-wayland.desktop  ubuntu.desktop
if [ -z "${ubuntu_wayland_sessions}" ]; then
    print_error "no ubuntu wayland session is available"
# Check that current session type is wayland (safer than X11 and Xorg)
elif ! [ "$XDG_SESSION_TYPE" == "wayland" ]; then
    print_error "wayland session type was not selected in login screen ($XDG_SESSION_TYPE)"
else
    print_success "wayland session type used"
fi
# Check that at least one ubuntu xsession is available (useful as a backup session in case of issues with desktops other than gnome)
ubuntu_xsessions=$(ls /usr/share/xsessions/ | grep -E "ubuntu.*\.desktop") # example of ls /usr/share/xsessions/ output: plasmax11.desktop  ubuntu-xorg.desktop  ubuntu.desktop
if [ -z "${ubuntu_xsessions}" ]; then
    print_warning "no ubuntu xsession is available"
else
    print_success "xsessions"
fi

echo
echo "---------- Check install ----------"
echo

customized_file_1="/etc/apt/apt.conf.d/10periodic" # file customized via Software & Updates / Updates tab
software_update_rate=$(cat "${customized_file_1}" | grep -E "Update-Package-Lists.*\"1\";")
if [ -z "${software_update_rate}" ]; then
    print_error "software update rate is not daily (can be updated in 'Software & Updates / Updates tab')"
fi
download_upgradeable_packages_0=$(cat "${customized_file_1}" | grep -E "Download-Upgradeable-Packages.*\"0\";")
download_upgradeable_packages_1=$(cat "${customized_file_1}" | grep -E "Download-Upgradeable-Packages.*\"1\";")
if [ -z "${download_upgradeable_packages_0}" ] && [ -z "${download_upgradeable_packages_1}" ]; then
    print_warning "cannot check download upgradeable packages"
fi
unattended_upgrade=$(cat "${customized_file_1}" | grep -E "Unattended-Upgrade.*\"0\";")
if [ -n "$download_upgradeable_packages_1" ] && [ -n "$unattended_upgrade" ]; then
    print_error "software update only downloads but does not install new packages (can be updated in 'Software & Updates / Updates tab')"
fi
if [ -d "${CHECKUP_FOLDER}/etc/apt/apt.conf.d" ]; then
    error_found=0
    diff "${CHECKUP_FOLDER}/etc/apt/apt.conf.d/10periodic" ${customized_file_1}
    if [ $? -ne 0 ]; then
        print_error "software update parameters have changed (${customized_file_1})"
        error_found=1
    fi

    if [ ${error_found} -eq 0 ]; then
        print_success "software update parameters"
    fi
else
    print_warning "software update parameters check is skipped because reference folder ${CHECKUP_FOLDER}/etc/apt/apt.conf.d does not exist"
fi

# Check startup applications and services
if [ -d "${CHECKUP_FOLDER}/.config/autostart" ]; then
    error_found=0
    diff -r "${CHECKUP_FOLDER}/.config/autostart" "${HOME}/.config/autostart/"
    if [ $? -ne 0 ]; then
        print_error "startup applications have changed (${HOME}/.config/autostart)"
        error_found=1
    fi

    if [ ${error_found} -eq 0 ]; then
        print_success "startup applications"
    fi
else
    print_warning "startup applications check is skipped because reference folder ${CHECKUP_FOLDER}/.config/autostart does not exist"
fi
if [ -f "${CHECKUP_FOLDER}/systemctl_services_enabled_sauv.txt" ]; then
    error_found=0
    systemctl list-unit-files --type=service --state=enabled > "${CHECKUP_FOLDER}/systemctl_services_enabled_current.txt"
    diff "${CHECKUP_FOLDER}/systemctl_services_enabled_sauv.txt" "${CHECKUP_FOLDER}/systemctl_services_enabled_current.txt"
    if [ $? -ne 0 ]; then
        print_error "startup services have changed"
        error_found=1
    fi

    if [ ${error_found} -eq 0 ]; then
        print_success "startup services"
    fi
else
    print_warning "startup services check is skipped because reference file ${CHECKUP_FOLDER}/.config/autostart does not exist"
fi

# Check PATH
if [ "$PATH" == "$EXPECTED_PATH" ]; then
    print_success "PATH environment variable"
else
    echo "expected PATH: $EXPECTED_PATH"
    echo "current PATH:  $PATH"
    print_error "PATH environment variable has changed"
fi

# Check errors in system logs
today_date=$(date +"%Y-%m-%d")
one_day_ago_date=$(date -d "yesterday" +"%Y-%m-%d")
two_days_ago_date=$(date -d "2 days ago" +"%Y-%m-%d")
three_days_ago_date=$(date -d "3 days ago" +"%Y-%m-%d")
four_days_ago_date=$(date -d "4 days ago" +"%Y-%m-%d")
five_days_ago_date=$(date -d "5 days ago" +"%Y-%m-%d")
six_days_ago_date=$(date -d "6 days ago" +"%Y-%m-%d")
seven_days_ago_date=$(date -d "7 days ago" +"%Y-%m-%d")
if ! [[ -e /var/log/syslog && -e /var/log/kern.log && -e /var/log/auth.log ]]; then # same list of files as below
    print_warning "some system logs files to be checked are missing"
fi
serious_errors_in_system_logs=$(more /var/log/syslog /var/log/kern.log /var/log/auth.log | grep -iP "$today_date|$one_day_ago_date|$two_days_ago_date|$three_days_ago_date|$four_days_ago_date|$five_days_ago_date|$six_days_ago_date|$seven_days_ago_date" | grep -iP "severe|critical|fatal|alert|emergency|panic|segfault" | grep -iv "not severe" | grep -iv "not critical" | grep -iv "not fatal")
if [ "${serious_errors_in_system_logs}" == "" ]; then
    print_success "system logs"
else
    echo "$serious_errors_in_system_logs"
    print_warning "above errors were found in system logs"
fi

echo
# Check firefox
if [ -d "${SNAP_FIREFOX_PROFILE_FOLDER}" ]; then
    error_found=0

    # Firefox settings
    firefox_contentblocking_setting=$(cat ${SNAP_FIREFOX_PROFILE_FOLDER}/prefs.js | grep "user_pref(\"browser.contentblocking.category\", \"standard\")")
    if [ -z "${firefox_contentblocking_setting}" ]; then
        print_error "firefox content blocking setting is not standard"
        error_found=1
    fi
    firefox_httpsonly_setting=$(cat ${SNAP_FIREFOX_PROFILE_FOLDER}/prefs.js | grep "user_pref(\"dom.security.https_only_mode\", true);")
    if [ -z "${firefox_httpsonly_setting}" ]; then
        print_error "firefox https only setting is disabled"
        error_found=1
    fi
    firefox_autofillcard_setting=$(cat ${SNAP_FIREFOX_PROFILE_FOLDER}/prefs.js | grep "user_pref(\"extensions.formautofill.creditCards.enabled\", false);")
    if [ -z "${firefox_autofillcard_setting}" ]; then
        print_error "firefox autofill card setting is enabled"
        error_found=1
    fi

    firefox_blockpopups_setting=$(cat ${SNAP_FIREFOX_PROFILE_FOLDER}/prefs.js | grep -i "dom.disable_open_during_load" | grep -i -P "(false|0)")
    if [ -n "${firefox_blockpopups_setting}" ]; then
        print_error "firefox block pop-ups setting is disabled"
        error_found=1
    fi
    # xpinstall.whitelist.required => whitelist
    firefox_addonsinstallwarning_setting=$(cat ${SNAP_FIREFOX_PROFILE_FOLDER}/prefs.js | grep -i "whitelist" | grep -i -P "(false|0)")
    if [ -n "${firefox_addonsinstallwarning_setting}" ]; then
        print_error "firefox addons install warning setting is disabled"
        error_found=1
    fi
    firefox_malwareblocking_setting=$(cat ${SNAP_FIREFOX_PROFILE_FOLDER}/prefs.js | grep -i "browser.safebrowsing.malware.enabled" | grep -i -P "(false|0)")
    if [ -n "${firefox_malwareblocking_setting}" ]; then
        print_error "firefox malware blocking setting is disabled"
        error_found=1
    fi
    firefox_phishingblocking_setting=$(cat ${SNAP_FIREFOX_PROFILE_FOLDER}/prefs.js | grep -i "browser.safebrowsing.phishing.enabled" | grep -i -P "(false|0)")
    if [ -n "${firefox_phishingblocking_setting}" ]; then
        print_error "firefox phishing blocking setting is disabled"
        error_found=1
    fi
    firefox_dangerousdownloadblocking_setting=$(cat ${SNAP_FIREFOX_PROFILE_FOLDER}/prefs.js | grep -i "browser.safebrowsing.downloads.enabled" | grep -i -P "(false|0)")
    if [ -n "${firefox_dangerousdownloadblocking_setting}" ]; then
        print_error "firefox dangerous download blocking setting is disabled"
        error_found=1
    fi
    firefox_dangerousuncommonsoftware_setting=$(cat ${SNAP_FIREFOX_PROFILE_FOLDER}/prefs.js | grep -i "browser.safebrowsing.downloads.remote.block_uncommon" | grep -i -P "(false|0)")
    if [ -n "${firefox_dangerousuncommonsoftware_setting}" ]; then
        print_error "firefox uncommon software blocking setting is disabled"
        error_found=1
    fi
    # wider safebrowsing coverage
    firefox_safebrowsing_settings=$(cat ${SNAP_FIREFOX_PROFILE_FOLDER}/prefs.js | grep -i "safebrowsing" | grep -i "false")
    if [ -n "${firefox_safebrowsing_settings}" ]; then
        echo "${firefox_safebrowsing_settings}"
        print_error "above firefox safebrowsing settings are disabled"
        error_found=1
    fi
    # security.OCSP.enabled => OCSP
    firefox_ocspquery_setting=$(cat ${SNAP_FIREFOX_PROFILE_FOLDER}/prefs.js | grep -i "OCSP" | grep -i -P "(false|0)")
    if [ -n "${firefox_ocspquery_setting}" ]; then
        print_error "firefox ocsp query setting is disabled"
        error_found=1
    fi

    if [ ${error_found} -eq 0 ]; then
        print_success "firefox settings"
    fi

    if [ -d "${CHECKUP_FOLDER}/firefox" ]; then
        # Firefox profile
        diff "${CHECKUP_FOLDER}/firefox/profiles_sauv.ini" "${SNAP_FIREFOX_FOLDER}/profiles.ini"
        if [ $? -ne 0 ]; then
            print_error "firefox profile has changed (${SNAP_FIREFOX_FOLDER}/profiles.ini)"
            error_found=1
        fi
        # Firefox extensions and plugins
        grep -oE '"name":"[^"]*"|"id":"[^"]*"|"sourceURI":"[^"]*"' "${CHECKUP_FOLDER}/firefox/addons_sauv.json" | sed 's/[0-9]\+/X/g' > "${CHECKUP_FOLDER}/firefox/addons_names_sauv_reformated.json"
        cat "${CHECKUP_FOLDER}/firefox/addons_names_sauv_reformated.json" | sort > "${CHECKUP_FOLDER}/firefox/addons_names_sauv_reformated_sorted.json"
        grep -oE '"name":"[^"]*"|"id":"[^"]*"|"sourceURI":"[^"]*"' "${SNAP_FIREFOX_PROFILE_FOLDER}/addons.json" | sed 's/[0-9]\+/X/g' > "${CHECKUP_FOLDER}/firefox/addons_names_current_reformated.json"
        cat "${CHECKUP_FOLDER}/firefox/addons_names_current_reformated.json" | sort > "${CHECKUP_FOLDER}/firefox/addons_names_current_reformated_sorted.json"
        sed 's/[0-9]\+/X/g' "${CHECKUP_FOLDER}/firefox/addons_sauv.json" | sed 's/},/},\n/g' > "${CHECKUP_FOLDER}/firefox/addons_sauv_reformated.json"
        sed 's/[0-9]\+/X/g' "${SNAP_FIREFOX_PROFILE_FOLDER}/addons.json" | sed 's/},/},\n/g' > "${CHECKUP_FOLDER}/firefox/addons_current_reformated.json"
        diff "${CHECKUP_FOLDER}/firefox/addons_names_sauv_reformated_sorted.json" "${CHECKUP_FOLDER}/firefox/addons_names_current_reformated_sorted.json"
        if [ $? -ne 0 ]; then
            print_error "above firefox addons names have changed (check changes and copy file ${SNAP_FIREFOX_PROFILE_FOLDER}/addons.json to ${CHECKUP_FOLDER}/firefox/addons_sauv.json)"
            error_found=1
        fi
        # Below check is too strict so is commented:
        # diff "${CHECKUP_FOLDER}/firefox/addons_sauv_reformated.json" "${CHECKUP_FOLDER}/firefox/addons_current_reformated.json"
        # if [ $? -ne 0 ]; then
        #     print_warning "firefox addons have changed (${SNAP_FIREFOX_PROFILE_FOLDER}/addons.json)"
        # fi
        grep -oE '"name":"[^"]*"|"id":"[^"]*|"path":"[^"]*|"rootURI":"[^"]*"' "${CHECKUP_FOLDER}/firefox/extensions_sauv.json" | sed 's/[0-9]\+/X/g' > "${CHECKUP_FOLDER}/firefox/extensions_names_sauv_reformated.json"
        cat "${CHECKUP_FOLDER}/firefox/extensions_names_sauv_reformated.json" | sort > "${CHECKUP_FOLDER}/firefox/extensions_names_sauv_reformated_sorted.json"
        grep -oE '"name":"[^"]*"|"id":"[^"]*|"path":"[^"]*|"rootURI":"[^"]*"' "${SNAP_FIREFOX_PROFILE_FOLDER}/extensions.json" | sed 's/[0-9]\+/X/g' > "${CHECKUP_FOLDER}/firefox/extensions_names_current_reformated.json"
        cat "${CHECKUP_FOLDER}/firefox/extensions_names_current_reformated.json" | sort > "${CHECKUP_FOLDER}/firefox/extensions_names_current_reformated_sorted.json"
        sed 's/[0-9]\+/X/g' "${CHECKUP_FOLDER}/firefox/extensions_sauv.json" | sed 's/},/},\n/g' > "${CHECKUP_FOLDER}/firefox/extensions_sauv_reformated.json"
        sed 's/[0-9]\+/X/g' "${SNAP_FIREFOX_PROFILE_FOLDER}/extensions.json" | sed 's/},/},\n/g' > "${CHECKUP_FOLDER}/firefox/extensions_current_reformated.json"
        diff "${CHECKUP_FOLDER}/firefox/extensions_names_sauv_reformated_sorted.json" "${CHECKUP_FOLDER}/firefox/extensions_names_current_reformated_sorted.json"
        if [ $? -ne 0 ]; then
            print_error "above firefox extensions names have changed (check changes and copy file ${SNAP_FIREFOX_PROFILE_FOLDER}/extensions.json to ${CHECKUP_FOLDER}/firefox/extensions_sauv.json)"
            error_found=1
        fi
        # Below check is too strict so is commented:
        # diff "${CHECKUP_FOLDER}/firefox/extensions_sauv_reformated.json" "${CHECKUP_FOLDER}/firefox/extensions_current_reformated.json"
        # if [ $? -ne 0 ]; then
        #     print_warning "firefox extensions have changed (${SNAP_FIREFOX_PROFILE_FOLDER}/extensions.json)"
        # fi

        if [ ${error_found} -eq 0 ]; then
            print_success "firefox install"
        fi
    else
        print_warning "firefox install check is partially skipped because reference folder ${CHECKUP_FOLDER}/firefox does not exist"
    fi
else
    print_error "firefox install check is skipped because firefox snap settings folder ${SNAP_FIREFOX_PROFILE_FOLDER} does not exist"
fi

default_browser=$(xdg-settings get default-web-browser)
firefox_as_default_browser=$(echo "$default_browser" | grep "firefox")
if [ -z "${firefox_as_default_browser}" ]; then
    print_warning "firefox is not the default browser (current default browser is $default_browser)"
fi

# Check chromium
if [ -d "${SNAP_CHROMIUM_FOLDER}" ]; then
    error_found=0

    # Chromium settings
    chromium_safebrowing_enabled=$(more "${SNAP_CHROMIUM_FOLDER}/Preferences" | grep -oE '"safebrowsing":{[^}]*}' | grep "\"enabled\":true")
    if [ -z "${chromium_safebrowing_enabled}" ]; then
        print_error "chromium browsing is not safe"
        error_found=1
    fi
    chromium_always_use_secure_connections_enabled=$(more "${SNAP_CHROMIUM_FOLDER}/Preferences" | grep "\"https_only_mode_enabled\":true")
    if [ -z "${chromium_always_use_secure_connections_enabled}" ]; then
        print_error "chromium 'always use secure connections' setting is disabled"
        error_found=1
    fi
    chromium_save_and_fill_payment_methods_disabled=$(more "${SNAP_CHROMIUM_FOLDER}/Preferences" | grep "\"credit_card_enabled\":false")
    if [ -z "${chromium_save_and_fill_payment_methods_disabled}" ]; then
        print_error "chromium 'save and fill payment methods' setting is enabled"
        error_found=1
    fi

    if [ ${error_found} -eq 0 ]; then
        print_success "chromium settings"
    fi
else
    print_error "chromium settings check is skipped because chromium snap settings folder ${SNAP_CHROMIUM_FOLDER} does not exist"
fi
# Chromium extensions
if [ -d "${SNAP_FOLDER}/chromium" ]; then
    # snap chromium extensions are located in ~/snap/chromium/.../Extensions
    chromium_extension_files=$(find ${SNAP_FOLDER}/chromium -type f -ipath "*Extensions*")
    if [ -n "${chromium_extension_files}" ]; then
        echo "${chromium_extension_files}"
        print_warning "chromium extensions were found, see above"
    else
        print_success "chromium extensions"
    fi
else
    print_error "chromium extensions check is skipped because chromium snap folder ${SNAP_FOLDER}/chromium does not exist"
fi

# Check installed package files storage
echo
echo "checking installed package files storage..."
# possible error observed at sudo dpkg --verify execution: ??5?????? c /etc/apt/apt.conf.d/10periodic (means that properties in this file don't match the package's expectations, typically following customization via Software & Updates / Updates tab) => ignored because /etc/apt/apt.conf.d/10periodic file contents were already checked above
dpkg_verify_status=$(sudo dpkg --verify | grep -v "/etc/apt/apt.conf.d/10periodic")
if [ -n "${dpkg_verify_status}" ]; then
    echo "${dpkg_verify_status}"
    print_error "errors in installed package files storage, possibly due to manual updates, file corruptions, file system errors on disk, see above (package reinstallation or package file restoration may be needed)"
else
    print_success "installed package files storage"
fi

echo
sudo apt-get check > /dev/null
if [ $? -eq 0 ]; then
    print_success "apt-get check"
else
    print_error "apt-get check"
fi

if [ -d "${CHECKUP_FOLDER}" ]; then
    error_found=0
    diff "${CHECKUP_FOLDER}/etc/apt/sources.list" "/etc/apt/sources.list"
    if [ $? -ne 0 ]; then
        print_error "repository list has changed (/etc/apt/sources.list)"
        error_found=1
    fi

    diff -r --exclude="*.save" "${CHECKUP_FOLDER}/etc/apt/sources.list.d" "/etc/apt/sources.list.d"
    if [ $? -ne 0 ]; then
        print_error "repository list has changed (/etc/apt/sources.list.d)"
        error_found=1
    fi

    apt-cache policy > "${CHECKUP_FOLDER}/apt-cache_policy_current.txt"
    diff "${CHECKUP_FOLDER}/apt-cache_policy_sauv.txt" "${CHECKUP_FOLDER}/apt-cache_policy_current.txt"
    if [ $? -ne 0 ]; then
        print_error "repository list has changed (apt-cache policy)"
        error_found=1
    fi

    if [ ${error_found} -eq 0 ]; then
        print_success "repository list"
    fi
else
    print_warning "repository list check is skipped because reference folder ${CHECKUP_FOLDER} does not exist"
fi

apt_list_installed=$(apt list --installed 2> /dev/null)
nb_packages_installed=$(echo "${apt_list_installed}" | wc -l)

# known unsafe packages
if echo "${apt_list_installed}" | grep -q "^vino"; then
    print_error "vino is installed (security risk)"
fi
if echo "${apt_list_installed}" | grep -q "^wine"; then
    print_error "wine is installed (security risk)"
fi
if echo "${apt_list_installed}" | grep -q "chrome"; then
    print_error "chrome is installed (snap chromium shall be preferred because open source)"
fi
if command -v kwallet-query &> /dev/null; then
    kde_wallet_unused=$(kwallet-query kdewallet -l 2> /dev/null | grep "The folder Passwords does not exist")
    if [ -z "${kde_wallet_unused}" ]; then
        print_warning "KDE wallet is used"
    fi
fi

# in ubuntu, snap is used by default instead of flatpak
if echo "${apt_list_installed}" | grep -q "flatpak"; then
    print_error "flatpak is installed (snap shall be preferred on ubuntu)"
fi

apt_cache_policy_all_packages=$(apt-cache policy $(dpkg-query -W -f='${binary:Package}\n'))

# proprietary drivers for devices supported by ubuntu but not open source
restricted_packages=$(echo "${apt_cache_policy_all_packages}" | grep -B5 'restricted')
if [ -n "$restricted_packages" ]; then
    echo "$restricted_packages"
    print_error "restricted packages are installed"
fi

# software not officially supported by ubuntu
multiverse_packages=$(echo "${apt_cache_policy_all_packages}" | grep -B5 'multiverse')
if [ -n "$multiverse_packages" ]; then
    echo "$multiverse_packages"
    print_error "multiverse packages are installed"
fi

# oracular-backports software (manually installed packages from backports repository do not receive security updates / there can be occasionally compatibility issues => to avoid for stability and security reasons)
# (backports repository can be seen in Software & Updates / Other Software tab, and shall not be removed if automatically listed here)
backports_packages=$(echo "${apt_cache_policy_all_packages}" | grep -B5 'backports')
if [ -n "$backports_packages" ]; then
    echo "$backports_packages"
    print_error "backports packages are installed"
fi

# obsolete packages
obsolete_packages=$(apt list ~o 2> /dev/null | grep -v "Listing...")
if [ -n "$obsolete_packages" ]; then
    echo "$obsolete_packages"
    print_warning "above packages are obsolete ('sudo apt remove' + 'sudo apt purge' to be run)"
fi

possibly_useless_packages=$(apt autoremove --dry-run 2> /dev/null | grep -P "(REMOV|Remv)")
if [ -n "$possibly_useless_packages" ]; then
    echo "$possibly_useless_packages"
    print_warning "above packages may be useless ('sudo apt autoremove [--dry-run] --purge' to be run to remove them all)"
fi

# Check snap packages
echo
echo "checking snap packages..."
snap_error_found=0
if [ -f "${CHECKUP_FOLDER}/snap_list_sauv.txt" ]; then
    # option --all of snap list is not used here because package revisions order is undeterministic
    snap list > "${CHECKUP_FOLDER}/snap_list_current.txt"
    # reformat to only keep Name, Tracking, Publisher and Notes columns
    awk '{print $1, $4, $5, $6}' "${CHECKUP_FOLDER}/snap_list_sauv.txt" > "${CHECKUP_FOLDER}/snap_list_sauv_reformated.txt"
    awk '{print $1, $4, $5, $6}' "${CHECKUP_FOLDER}/snap_list_current.txt" > "${CHECKUP_FOLDER}/snap_list_current_reformated.txt"
    snap_list_sauv_contents_check=$(cat "${CHECKUP_FOLDER}/snap_list_sauv_reformated.txt" | grep "Name Tracking Publisher Notes")
    if [ -z "${snap_list_sauv_contents_check}" ]; then
        print_error "snap package list is not properly reformated (${CHECKUP_FOLDER}/snap_list_sauv_reformated.txt)"
        snap_error_found=1
    fi
    diff "${CHECKUP_FOLDER}/snap_list_sauv_reformated.txt" "${CHECKUP_FOLDER}/snap_list_current_reformated.txt"
    if [ $? -ne 0 ]; then
        print_error "snap package list has changed"
        snap_error_found=1
    fi
else
    print_warning "snap package list check is skipped because reference file "${CHECKUP_FOLDER}/snap_list_sauv.txt" does not exist"
fi
if snap debug confinement | grep -v "strict"; then
    print_error "above default confinement mode for snap packages is not strict"
    snap_error_found=1
fi
if snap list --all | grep -v " canonical\*" | grep -v " kde\*" | grep -v " mozilla\*" | grep -v " openprinting\*" | grep -v " james-carroll\*" | grep -v "     Publisher     "; then # james-carroll for pinta snap package
    print_error "above snap packages have an unexpected publisher"
    snap_error_found=1
fi
if snap list --all | grep -v "/stable" | grep -v "     Publisher     "; then
    print_error "above snap packages are not stable"
    snap_error_found=1
fi
if snap list --all | grep -E " held|held$"; then
    print_error "above snap packages have updates disabled ('sudo snap refresh --unhold' to be run to enable updates)"
    snap_error_found=1
fi
snap_refresh_retain=$(sudo snap get system refresh.retain)
if ! [ ${snap_refresh_retain} -eq 2 ]; then
    print_error "snap refresh.retain is not set to its lowest possible value (2): old snap packages (which can be listed with 'snap list --all | grep disabled') can consume too much disk space ('sudo snap set system refresh.retain=2' to be run)"
    snap_error_found=1
fi
snap_package_info=$(snap list --all | awk 'NR>1 {print $1}' | while read snap; do echo "$snap: $(snap info --verbose $snap)"; done)
snap_package_confinements=$(echo "$snap_package_info" | grep 'confinement')
snap_packages_with_non_strict_confinement=$(echo "${snap_package_confinements}" | grep -v 'strict')
if [ -n "${snap_packages_with_non_strict_confinement}" ]; then
    echo "${snap_packages_with_non_strict_confinement}"
    print_error "some snap packages are not installed with strict confinement"
    snap_error_found=1
fi
snap_package_urls=$(echo "$snap_package_info" | grep 'store-url')
snap_packages_with_unexpected_urls=$(echo "${snap_package_urls}" | grep -v 'https://snapcraft.io/')
if [ -n "${snap_packages_with_unexpected_urls}" ]; then
    echo "${snap_packages_with_unexpected_urls}"
    print_error "some snap packages are installed from an unexpected URL (this error can appear if no network connection)"
    snap_error_found=1
fi
snap_package_licenses=$(echo "$snap_package_info" | grep 'license:')
snap_packages_with_unexpected_licenses=$(echo "${snap_package_licenses}" | grep -v 'unset' | grep -v 'GPL' | grep -v 'MIT') # "license:   Proprietary" will be detected
if [ -n "${snap_packages_with_unexpected_licenses}" ]; then
    echo "${snap_packages_with_unexpected_licenses}"
    print_error "some snap packages are installed with an unexpected license"
    snap_error_found=1
fi
if snap saved | grep -v "No snapshots found."; then
    print_warning "above snap snapshots are stored ('sudo snap forget <snapshot_id>' to be run to forget them)"
fi
# check that some snap packages do not have access to internet for security reasons (pinta snap package here, if installed)
pinta_network_connection=$(snap connections | grep pinta | grep network)
if [ -n "${pinta_network_connection}" ]; then
    echo "${pinta_network_connection}"
    print_error "pinta snap package has internet access ('sudo snap disconnect pinta:network' to be run)"
    snap_error_found=1
fi
if [ ${snap_error_found} -eq 0 ]; then
  print_success "snap packages"
fi

# Check installed packages in details
echo
echo "checking installed packages in details..."
packages_with_updates_disabled=$(apt-mark showhold)
if [ -n "${packages_with_updates_disabled}" ]; then
    echo "${packages_with_updates_disabled}"
    print_error "above packages have updates disabled ('sudo apt-mark unhold' to be run to enable updates)"
fi
package_index=1
for pkg in $(dpkg-query -W -f='${binary:Package}\n'); do
    pkg_policy=$(apt-cache policy "${pkg}")
    package_errors_str=""
    # Not-authenticated packages
    if ! $(echo "${pkg_policy}" | grep -q "500 http"); then
        package_errors_str="non-authenticated! ${package_errors_str}"
    fi
    repo_url=$(echo "${pkg_policy}" | grep -P "(http|https)://[^ ]+")
    # echo "${pkg}: ${repo_url}"
    if [ -z "${repo_url}" ]; then
        package_errors_str="no URL! ${package_errors_str}"
    fi
    # Official repository URLs as in ubuntu.sources file
    if echo "${repo_url}" | grep -v "http://archive.ubuntu.com/ubuntu" | grep -v "http://security.ubuntu.com/ubuntu" > /dev/null; then
        package_errors_str="non-official! ${package_errors_str}"
    fi
    if [ -n "${package_errors_str}" ]; then
        # Handle exceptions like:
        # linux-image-6.11.0-9-generic
        # linux-modules-6.11.0-9-generic
        # linux-modules-extra-6.11.0-9-generic
        if [[ ${pkg} == *"linux-image-"* || ${pkg} == *"linux-modules-"* ]]; then
            print_info "${package_errors_str}for package ${pkg}"
        else
            print_error "${package_errors_str}for package ${pkg}"
        fi
    fi

    # PPA (Personal Package Archive) packages (e.g. http://ppa.xxx) not available in official ubuntu repositories
    # example of PPA package: http://ppa.launchpad.net/libreoffice/ppa/...
    if echo "${repo_url}" | grep -q "/ppa"; then
        print_error "PPA package is installed (/ppa): ${pkg}"
    elif echo "${repo_url}" | grep -q "launchpad.net"; then
        print_error "PPA package is installed (launchpad.net): ${pkg}"
    fi

    percentage=$((100 * package_index / nb_packages_installed))
    if (( package_index == 50 )) || (( package_index == 100 )) || (( package_index == 200 )) || (( package_index % 400 == 0 )) || (( package_index == nb_packages_installed )); then
        echo "${percentage}% (${package_index}/${nb_packages_installed})"
    fi
    package_index=$((package_index+1))
done
print_success "installed packages, see above logs for any warnings/errors"

echo
if [ ${nb_errors} -eq 0 ]; then
    if [ ${nb_warnings} -eq 0 ]; then
        echo -e "*** DONE ${GREEN}(success)${NC} ***"
    else
        echo -e "*** DONE ${YELLOW}with ${nb_warnings} warning(s)${NC} ***"
    fi
else
    if [ ${nb_warnings} -eq 0 ]; then
        echo -e "*** DONE ${RED}with ${nb_errors} errors(s)${NC} ***"
    else
        echo -e "*** DONE ${RED}with ${nb_errors} errors(s)${NC} + ${YELLOW}with ${nb_warnings} warning(s)${NC} ***"
    fi
fi

echo
read -p "Press Enter to start updates..."
echo

echo "---------- Updates ----------"
echo

${SCRIPT_FOLDER}/update.sh
