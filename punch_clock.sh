#!/bin/sh

#- POSIX compliant shell script to keep track of the time i have been working.
#- Needs another script that can add and subtract hours (00:00) and convert minutes to HH:MM.
#- This other script is provided at https://raw.githubusercontent.com/lrr68/punch_the_clock/main/date_time.sh and https://raw.githubusercontent.com/lrr68/rice/master/.local/bin/data_hora

# Script capable of doing operations with date and time
DATEMATHICS="date_time.sh"
TIMEFILE="$HOME/.time/workhoursmonth.csv"
FULLTIMEFILE="$HOME/.time/workhours.csv"
HEADER="day, login time, pauses (in minutes), logout time, extra hours, worked hours"

DATE=$(date +%Y-%m-%d)
TIME=""

gettimeworked()
{
	TODAY=$(grep -r "^$DATE" "$TIMEFILE")
	LOGINTIME="$(echo "$TODAY" | awk '{print $2}')"
	LOGINTIME=${LOGINTIME%,}
	TIMEWORKED=$($DATEMATHICS -s "$TIME" "$LOGINTIME")
	PAUSES=$(echo "$TODAY" | awk '{print $3}')
	PAUSES=${PAUSES%,}

	echo $((TIMEWORKED - PAUSES))
}

showtimeworked()
{
	TIME=$(date +%H:%M)
	WORKED="$(gettimeworked)"
	echo "$($DATEMATHICS -h "$WORKED") Hours worked"
}

loglogin()
{
	TIME=$(date +%H:%M)
	TODAY=$(grep -r "^$DATE" "$TIMEFILE")

	if [ ! "$TODAY" ]
	then
		YESTERDAY=$(tail -n 1 $TIMEFILE)
		Y_MONTH=${YESTERDAY%-*}
		Y_MONTH=${Y_MONTH#*-}
		T_MONTH=${DATE%-*}
		T_MONTH=${T_MONTH#*-}
		# changed the month, append timefile to the global time file and begin a new monthly time file
		if [ "$Y_MONTH" -lt "$T_MONTH" ]
		then
			[ -e "$FULLTIMEFILE" ] ||
				echo "$HEADER" > "$FULLTIMEFILE"

			tail -n +2 "$TIMEFILE" >> "$FULLTIMEFILE"
			echo "$HEADER" > "$TIMEFILE"
		fi
		echo "$DATE, $TIME, 0," >> "$TIMEFILE"
		echo "TRUE" > "$HOME/.working"
	else
		[ -e "$HOME/.working" ] && echo "Already Logged In" && return

		LOGGEDOUT="$(echo "$TODAY" | awk '{print $4}')"
		if [ "$LOGGEDOUT" ]
		then
			echo "$TIME" > "$HOME/.working"
		fi
	fi
}

takebreak()
{
	echo "FALSE" > "$HOME/.working"
	"$(date +%H:%M)" > "$HOME/.pause"
}

resumework()
{
	STOPPED=$(cat "$HOME/.pause")
	NOW=$(date +%H:%M)

	logpause "$($DATEMATHICS -s "$NOW" "$STOPPED")"
	echo TRUE > "$HOME/.working"
	rm "$HOME/.pause"
}

logpause()
{
	DOWNTIME="$1"
	if [ "$DOWNTIME" ]
	then
		TODAY=$(grep -r "^$DATE" "$TIMEFILE")
		TODAYPAUSE=$(echo "$TODAY" | awk '{print $3}')
		TODAYPAUSE=${TODAYPAUSE%,}
		TOTALDOWNTIME=$((TODAYPAUSE + DOWNTIME))

		LOGGEDOUT="$(echo "$TODAY" | awk '{print $4}')"
		if [ "$LOGGEDOUT" ]
		then
			NEWLINE=$(echo "$TODAY" | awk '{print $1" " $2" " '$TOTALDOWNTIME'", " $4" " $5" " $6}')
		else
			NEWLINE=$(echo "$TODAY" | awk '{print $1" " $2" " '$TOTALDOWNTIME'","}')
		fi
		[ "$NEWLINE" ] &&
			sed "s/$TODAY/$NEWLINE/g" < "$TIMEFILE" > "$TIMEFILE.aux" &&
			mv "$TIMEFILE.aux" "$TIMEFILE"
	else
		echo "ERROR: To log a pause inform pause time"
	fi
}

loglogout()
{
	if [ ! -e "$HOME/.working" ]
	then
		TIME=$(date +%H:%M)
		TODAY=$(grep -r "^$DATE" "$TIMEFILE")
		TIMEWORKED=$(gettimeworked)

		LOGGEDOUT="$(echo "$TODAY" | awk '{print $4}')"
		if [ ! "$LOGGEDOUT" ]
		then
			# compute work hours
			NEWLINE="$TODAY $TIME, 00:00, $("$DATEMATHICS" -h "$TIMEWORKED")"
		else
			# compute extra hours
			LOGIN="$(cat "$HOME/.working")"

			EXTRAWORKED="$(echo "$TODAY" | awk '{print $5}')"
			EXTRAWORKED=${EXTRAWORKED%,}
			EXTRA="$($DATEMATHICS -s "$TIME" "$LOGIN")"
			EXTRA="$($DATEMATHICS -h "$EXTRA")"
			EXTRA="$($DATEMATHICS -a "$EXTRA" "$EXTRAWORKED")"

			TOTALTIME="$(gettimeworked)"
			TOTALTIME="$($DATEMATHICS -h "$TOTALTIME")"
			TOTALTIME="$($DATEMATHICS -a "$EXTRA" "$TOTALTIME")"

			NEWLINE="$(echo "$TODAY" | awk '{print $1" " $2" " $3" " $4}') $EXTRA, $TOTALTIME"
		fi

		sed "s/$TODAY/$NEWLINE/g" < "$TIMEFILE" >"$TIMEFILE.aux" &&
			mv "$TIMEFILE.aux" "$TIMEFILE"
		rm "$HOME/.working"
	else
		echo "You must be logged in to logout"
	fi
}

timetilexit()
{
	TIME=$(date +%H:%M)
	TIMEWORKED=$(gettimeworked)
	TIMELEFT=$(( 480 - "$TIMEWORKED"))
	if [ "$TIMELEFT" -lt 1 ]
	then
		MSG="You're already working over hours for ${TIMELEFT#-} minutes"
	else
		HOURSLEFT=$($DATEMATHICS -h "$TIMELEFT")
		MSG="$HOURSLEFT left, estimated exit: $(data_hora -a "$TIME" "$HOURSLEFT")"
	fi

	[ "$1" = "notify" ] &&
		notify-send "$MSG" ||
		echo "$MSG"

	balance="$(getbalance)"
	balance_in_hours="$($DATEMATHICS -h "$balance")"
	if [ "$balance" -lt 0 ]
	then
		if [ "$balance" -gt "$TIMELEFT" ]
		then
			echo "Stop working now and use $($DATEMATHICS -s "$balance_in_hours" "$HOURSLEFT") extra hours"
		else
			left_minus_extra_hours="$($DATEMATHICS -s "$HOURSLEFT" "$balance_in_hours")"
			hours_left_minus_extra="$($DATEMATHICS -h "$left_minus_extra_hours")"
			extra_use="$($DATEMATHICS -s "$HOURSLEFT" "$hours_left_minus_extra")"
			extra_use="$($DATEMATHICS -h "$extra_use")"
			left_used_extra="$($DATEMATHICS -s "$balance_in_hours" "$extra_use")"
			left_used_extra="$($DATEMATHICS -h "$left_used_extra")"
			if [ "$left_minus_extra_hours" -lt 1 ]
			then
				echo "Stop working now and still have $hours_left_minus_extra extra hours."
			else
				echo "Work only $($DATEMATHICS -h "$left_minus_extra_hours") and use $extra_use extra hours."
			fi
		fi
	else
		echo "Work $($DATEMATHICS -a "$HOURSLEFT" "$balance_in_hours") and pay the $balance_in_hours hours you owe"
	fi
}

getweekday()
{
	[ ! "$1" ] && echo "0" && return

	date="${1%,}"; shift
	day="${date##*-}"

	calline="$(cal -v "$date" | grep " $day ")"

	echo "$calline" | awk '{print $1}'
}

getexpectedhours()
{
	[ ! "$1" ] && echo "0" && return

	EXPECTED_HOURS=0

	NUMBER_OF_DAYS="$1"; shift

	for line in $(tail -n "$NUMBER_OF_DAYS" "$TIMEFILE" | awk '{print $1}')
	do
		date="${line%%,*}"
		weekday=$(getweekday "$date")
		if [ ! "$weekday" = "Sa" ] && [ ! "$weekday" = "Su" ]
		then
			EXPECTED_HOURS=$((EXPECTED_HOURS + 480))
		fi
	done

	echo "$EXPECTED_HOURS"
}

getbalance()
{
	TOTAL="00:00"
	BALANCE=0
	MSG=""

	TODAY=$(grep -r "^$DATE" "$TIMEFILE")
	LOGGEDOUT="$(echo "$TODAY" | awk '{print $4}')"

	# Do not count header
	NUMBER_OF_DAYS=$(wc -l < "$TIMEFILE")
	NUMBER_OF_DAYS=$((NUMBER_OF_DAYS -1))

	# Only take into account week days, worked weekends are extra hours
	# Do not take today into account if i have not logged out
	if [ ! "$LOGGEDOUT" ]
	then
		EXPECTED_N_MINUTES=$(getexpectedhours $((NUMBER_OF_DAYS - 1)))
		HOURS_WORKED_LIST="$(tail -n "$NUMBER_OF_DAYS" "$TIMEFILE" | head -n -1 | awk '{print $6}')"
	else
		EXPECTED_N_MINUTES=$(getexpectedhours "$NUMBER_OF_DAYS")
		HOURS_WORKED_LIST="$(tail -n "$NUMBER_OF_DAYS" "$TIMEFILE" | awk '{print $6}')"
	fi

	for hours in $HOURS_WORKED_LIST
	do
		TOTAL=$($DATEMATHICS -a "$TOTAL" "$hours")
	done

	#convert total to minutes so it's easier to operate
	TOTAL="$($DATEMATHICS -m "$TOTAL")"
	BALANCE=$((EXPECTED_N_MINUTES - TOTAL))

	echo "$BALANCE"
}

showbalance()
{
	BALANCE="$(getbalance)"

	if [ "$BALANCE" -lt 0 ]
	then
		# make it positive
		BALANCE=${BALANCE#-}
		MSG="You have $($DATEMATHICS -h "$BALANCE") extra hours"
	else
		MSG="You owe $($DATEMATHICS -h "$BALANCE") hours"
	fi

	echo "$MSG"
}

showtimefile()
{
	column -s',' -t < "$TIMEFILE"
	[ "$(wc -l < "$TIMEFILE")" -lt 2 ] && return
	showbalance
}

getstatus()
{
	STATUS="$(cat "$HOME/.working")"
	if [ "$STATUS" = "TRUE" ]
	then
		echo Working normal hours
	elif [ "$STATUS" = "FALSE" ]
	then
		echo On a break
	elif [ -n "$STATUS" ]
	then
		echo Working extra hours
	else
		echo Not working
	fi
}

# RUNNING
[ -e "$TIMEFILE" ] ||
	echo "$HEADER" > "$TIMEFILE"

arg="$1"; shift

case "$arg" in
	login)
		loglogin
		;;
	break)
		takebreak
		;;
	resume)
		resumework
		;;
	logpause)
		logpause "$1"
		;;
	logout)
		loglogout
		;;
	left)
		timetilexit "$1"
		;;
	timeworked)
		showtimeworked
		;;
	balance)
		showbalance
		;;
	status)
		getstatus
		;;
	show)
		showtimefile "$1"
		;;
	*)
		echo "usage: ${0##*/} ( command )"
		echo "commands:"
		echo "		login: Register the login time and sets status as working"
		echo "		logpause <time in minutes>: Register a pause of X minutes where X is the time informed"
		echo "		logout: Register the logout time and removes the working status"
		echo "		break: Register the time you are taking a break"
		echo "		resume: Remove the break status and register the time you have been out"
		echo "		left [ notify ]: Informs time left for you to complete 8 hours of work"
		echo "		timeworked: Informs time you have already worked in this session"
		echo "		balance: Shows if you have extra hours or owe hours (40 hour weeks)"
		echo "		show: Shows the timefile"
		echo "		status: Shows the working status"
		;;
esac
