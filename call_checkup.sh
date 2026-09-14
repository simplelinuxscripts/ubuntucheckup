###############################
# Call checkup.sh conditionally
###############################

SCRIPT_FOLDER=$(dirname "$0")
TIMESTAMP_FILE="$SCRIPT_FOLDER/_last_checkup_run.txt"
MIN_TIME_BTW_2_EXECUTIONS=$((21 * 24 * 3600)) # 21 days
LAST_RUN_TEXT="N.A."
ELAPSED_DAYS_TEXT="N.A."

# Check date of last checkup.sh run
if [ -f "$TIMESTAMP_FILE" ]; then
    LAST_RUN=$(cat "$TIMESTAMP_FILE")
    NOW=$(date +%s)
    ELAPSED=$((NOW - LAST_RUN))
    LAST_RUN_TEXT=$(date -d "@$LAST_RUN" "+%d-%m-%Y")
    ELAPSED_DAYS=$((ELAPSED / 86400))
    if [ "$ELAPSED_DAYS" -le 1 ]; then
        ELAPSED_DAYS_TEXT="very recent"
    else
        ELAPSED_DAYS_TEXT="$ELAPSED_DAYS days ago"
    fi
    if [ "$ELAPSED" -lt "$MIN_TIME_BTW_2_EXECUTIONS" ]; then
        echo "Last run was $ELAPSED_DAYS_TEXT ($LAST_RUN_TEXT), system checkup is skipped"
        exit 0
    fi
fi

if ! zenity --question --text="Do you want to do a system checkup?\nLast run was $ELAPSED_DAYS_TEXT ($LAST_RUN_TEXT)"; then
    exit 0
fi

# Run checkup
$SCRIPT_FOLDER/checkup.sh

# Update or create timestamp file with current time in seconds
date +%s > "$TIMESTAMP_FILE"
