#!/usr/bin/env bash
#############################################################
#                                                           #
# Privex's Shell Core                                       #
# Cross-platform / Cross-shell helper functions             #
#                                                           #
# Released under the GNU GPLv3                              #
#                                                           #
# Official Repo: github.com/Privex/shell-core               #
#                                                           #
#############################################################
#
# Various Bash Helper Functions for working with dates
# and times, including conversion to and from 
# seconds / UNIX epoch time.
#
# Included:
#   - rfc-datetime - Simple alias to generate an RFC 3399 / ISO 8601
#                    format date/time in the UTC timezone
#   - date-to-seconds - Convert an RFC/ISO date/time into UNIX epoch
#   - seconds-to-date - Convert UNIX epoch into an RFC/ISO datetime
#   - compare-dates   - Calculates how many seconds there are between two dates
#   - human-seconds   - Converts a number of seconds into humanized time,
#                       e.g. human-seconds 500   = 8 minute(s) and 20 second(s)
# -----------------------------------------------------------
#
# Most parts written by Someguy123 https://github.com/Someguy123
# Some parts copied from elsewhere e.g. StackOverflow - but often improved by Someguy123
#
#####################


# Check that both SG_LIB_LOADED and SG_LIBS exist. If one of them is missing, then detect the folder where this
# script is located, and then source map_libs.sh using a relative path from this script.
{ [ -z ${SG_LIB_LOADED[@]+x} ] || [ -z ${SG_LIBS[@]+x} ]; } && source "${_XDIR}/../map_libs.sh" || true
SG_LIB_LOADED[datehelpers]=1 # Mark this library script as loaded successfully
# sg_load_lib logging colors # Check whether 'colors' and 'logging' have already been sourced, otherwise source them.


######
# Very simple alias function which simply calls 'date' with the timezone env var TZ 
# locked to 'UTC', and a date formatting string to generate an RFC 3399 / ISO 8601
# standard format date/time.
# Example output:
#   $ rfc-datetime
#   2021-03-31T22:36:19
#
rfc-datetime() {
    TZ='UTC' date +'%Y-%m-%dT%H:%M:%S'
}

rfc_datetime() { rfc-datetime "$@"; }

_OS_NAME="$(uname -s)"

export SECS_MIN=60 SECS_MINUTE=60
export SECS_HOUR=$(( SECS_MIN * 60 ))
export SECS_DAY=$(( SECS_HOUR * 24 ))
export SECS_WEEK=$(( SECS_DAY * 7 ))
export SECS_MONTH=$(( SECS_WEEK * 4 ))
export SECS_YEAR=$(( SECS_DAY * 365 ))
export SECS_HR="$SECS_HOUR" SECS_WK="$SECS_WEEK" SECS_MON="$SECS_MONTH" SECS_YR="$SECS_YEAR"

# export SECS_MIN SECS_HOUR SECS_DAY SECS_WEEK SECS_MONTH SECS_YEAR
# export SECS_HR SECS_WK SECS_MON SECS_YR

export ISO_FMTSTR="%Y-%m-%dT%H:%M:%S"

# date-to-seconds [date_time]
# Convert a date/time string into UNIX time (epoch seconds)
# (alias 'date-to-unix')
# 
# for most reliable conversion, pass date/time in ISO format:
#       2020-02-28T20:08:09   (%Y-%m-%dT%H:%M:%S)
# e.g.
#   $ date_to_seconds "2020-02-28T20:08:09"
#   1582920489
#
date-to-seconds() {
    if [[ "$_OS_NAME" == "Darwin" ]]; then
        date -j -f "$ISO_FMTSTR" "$1" "+%s"
    else
        date -d "$1" '+%s'
    fi
}

date-to-unix() { date-to-seconds "$@"; }
date_to_seconds() { date-to-seconds "$@"; }

seconds-to-date() {
    if [[ "$_OS_NAME" == "Darwin" ]]; then
        date -j -f "%s" "$1" "+${ISO_FMTSTR}"
    else
        date -d "@$1" "+${ISO_FMTSTR}"
    fi
}
unix-to-date() { seconds-to-date "$@"; }

[[ $(ident_shell) == "bash" ]] && export -f date-to-seconds date-to-unix date_to_seconds seconds-to-date unix-to-date || \
    export date-to-seconds date-to-unix date_to_seconds seconds-to-date unix-to-date

# compare-dates [rfc_date_1] [rfc_date_2]
# outputs the amount of seconds between date_2 and date_1
#
# e.g.
#   $ compare-dates "2020-03-19T23:08:49" "2020-03-19T20:08:09"
#   10840
# means date_1 is 10,840 seconds in the future compared to date_2
#
compare-dates() {
    echo "$(($(date_to_seconds "$1")-$(date_to_seconds "$2")))"
}
compare_dates() { compare-dates "$@"; }

[[ $(ident_shell) == "bash" ]] && export -f compare-dates compare_dates || export compare-dates compare_dates

#######
# The following human-seconds-xxx functions are primarily intended for internal
# use by 'human-seconds', however, they're exported to allow you to use them directly,
# for cases where you need to use a specific scale, regardless of the size of your seconds.
#######

human-seconds-min() {
    local secs="$1"
    mins=$(( secs / SECS_MIN )) rem_secs=$(( secs % SECS_MIN ))
    (( rem_secs > 0 )) && echo "$mins minute(s) and $rem_secs second(s)" || echo "$mins minute(s)"
}

human-seconds-hour() {
    local secs="$1"
    hrs=$(( secs / SECS_HR )) rem_mins=$(( ( secs % SECS_HR ) / SECS_MIN ))
    (( rem_mins > 0 )) && echo "$hrs hour(s) and $rem_mins minute(s)" || echo "$hrs hour(s)"
}

human-seconds-day() {
    local secs="$1"
    days=$(( secs / SECS_DAY )) rem_hrs=$(( ( secs % SECS_DAY ) / SECS_HR ))
    rem_mins=$(( (( secs % SECS_DAY ) % SECS_HR) / SECS_MIN ))
    m="$days day(s)"
    (( rem_hrs > 0 )) && m="${m} + $rem_hrs hour(s)"
    (( rem_mins > 0 )) && m="${m} + $rem_mins minute(s)"
    echo "$m"
}

human-seconds-week() {
    local secs="$1"
    weeks=$(( secs / SECS_WK )) rem_days=$(( ( secs % SECS_WK ) / SECS_DAY ))
    rem_hrs=$(( (( secs % SECS_WK ) % SECS_DAY) / SECS_HR ))
    m="$weeks week(s)"
    (( rem_days > 0 )) && m="${m} + $rem_days day(s)"
    (( rem_hrs > 0 )) && m="${m} + $rem_hrs hour(s)"
    echo "$m"
}

human-seconds-month() {
    local secs="$1"
    months=$(( secs / SECS_MON )) rem_days=$(( ( secs % SECS_MON ) / SECS_DAY ))
    rem_hrs=$(( (( secs % SECS_MON ) % SECS_DAY) / SECS_HR ))
    m="$months month(s)"
    (( rem_days > 0 )) && m="${m} + $rem_days day(s)"
    (( rem_hrs > 0 )) && m="${m} + $rem_hrs hour(s)"
    echo "$m"
}

human-seconds-year() {
    local secs="$1"
    years=$(( secs / SECS_YR )) rem_months=$(( ( secs % SECS_YR ) / SECS_MON ))
    rem_days=$(( (( secs % SECS_YR ) % SECS_MON) / SECS_DAY ))
    m="$years years(s)"
    (( rem_months > 0 )) && m="${m} + $rem_months month(s)"
    (( rem_days > 0 )) && m="${m} + $rem_days day(s)"
    echo "$m"
}

[[ $(ident_shell) == "bash" ]] && export -f human-seconds-min human-seconds-hour human-seconds-day human-seconds-week human-seconds-month human-seconds-year || \
    export human-seconds-min human-seconds-hour human-seconds-day human-seconds-week human-seconds-month human-seconds-year

# internal function used by human-seconds to parse max_scale
_human_scale() {
    case "$1" in
        s|sec*|S|SEC*) echo "secs" ;;
        m|min*|MIN*) echo "min" ;;
        h|hr*|hour*|H|HR*|HOUR*) echo "hr" ;;
        d|day*|D|DAY*) echo "day" ;;
        w|wk*|week*|W|WK*|WEEK*) echo "week" ;;
        M|mo*|MO*) echo "mon";;
        y|yr*|yea*|Y|YR*|YEA*) echo "year" ;;
    esac
}

# human-seconds seconds [max_scale='year']
# convert an amount of seconds into a humanized time (minutes, hours, days)
#
#   human-seconds 60      # output: 1 minute(s)
#   human-seconds 4000    # output: 1 hour(s) and 6 minute(s)
#   human-seconds 90500   # output: 1 day(s) + 1 hour(s) + 8 minute(s)
#
# Limit the maximum scale (mins, hours, days, etc.):
# 
#   human-seconds 50000000 yr    # 1 years(s) + 7 month(s) + 17 day(s)
#   human-seconds 50000000 mon   # 20 month(s) + 18 day(s) + 16 hour(s)
#   human-seconds 50000000 wk    # 82 week(s) + 4 day(s) + 16 hour(s)
#   human-seconds 90500 hours    # 25 hour(s) and 8 minute(s)
#   human-seconds 90500 m        # 1508 minute(s) and 20 second(s)
#
# NOTE: max_scale supports most unit variations, e.g. m/min/minutes/mins, 
#       h/hrs/HOURS, M/mo/mons/months, w/wks/week/WEEKS/W, y/yrs/yea/year/Y/YRS 
#       and others similar variations.
#
human-seconds() {
    local secs="$1" mscl="year" mins hrs days
    local rem_secs rem_mins rem_hrs m
    (( $# > 1 )) && mscl="$(_human_scale "$2")"
    if (( secs < 60 )) || [[ "$mscl" == "secs" ]]; then       # less than 1 minute
        echo "$secs seconds"
    elif (( secs < 3600 )) || [[ "$mscl" == "min" ]]; then   # less than 1 hour
        human-seconds-min "$1"
    elif (( secs < 86400 )) || [[ "$mscl" == "hr" ]]; then   # less than 1 day
        human-seconds-hour "$1"
    elif (( secs < SECS_WK )) || [[ "$mscl" == "day" ]]; then
        human-seconds-day "$1"
    elif (( secs < SECS_MON )) || [[ "$mscl" == "week" ]]; then
        human-seconds-week "$1"
    elif (( secs < SECS_YR )) || [[ "$mscl" == "mon" ]]; then
        human-seconds-month "$1"
    else
        human-seconds-year "$1"
    fi
}

human_seconds() { human-seconds "$@"; }

[[ $(ident_shell) == "bash" ]] && export -f human_seconds human-seconds || export human_seconds human-seconds

if [[ $(ident_shell) == "bash" ]]; then
    export -f compare-dates compare_dates date-to-seconds date-to-unix date_to_seconds rfc-datetime rfc_datetime >/dev/null
    export -f human-seconds human_seconds human-seconds-min human-seconds-hour human-seconds-day human-seconds-week  >/dev/null
    export -f human-seconds-month human-seconds-year  >/dev/null
elif [[ $(ident_shell) == "zsh" ]]; then
    export compare-dates compare_dates date-to-seconds date-to-unix date_to_seconds rfc-datetime rfc_datetime >/dev/null
    export human-seconds human_seconds human-seconds-min human-seconds-hour human-seconds-day human-seconds-week  >/dev/null
    export human-seconds-month human-seconds-year  >/dev/null
else
    msgerr bold red "WARNING: Could not identify your shell. Attempting to export with plain export..."
    export compare-dates compare_dates date-to-seconds date-to-unix date_to_seconds rfc-datetime rfc_datetime >/dev/null
    export human-seconds human_seconds human-seconds-min human-seconds-hour human-seconds-day human-seconds-week  >/dev/null
    export human-seconds-month human-seconds-year  >/dev/null
fi
