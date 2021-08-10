#!/bin/sh

#- POSIX compliant shell script to keep track of the time i have been working.
#- Needs another script that can add and subtract hours (00:00) and convert minutes to HH:MM.
#- This other script is provided at https://raw.githubusercontent.com/lrr68/punch_the_clock/main/date_time.sh and https://raw.githubusercontent.com/lrr68/rice/master/.local/bin/data_hora

# Script capable of doing operations with date and time
datemathics="date_time.sh"
timefile="$HOME/.time/workhoursmonth.csv"
fulltimefile="$HOME/.time/workhours.csv"
header="day, login time, pauses (in minutes), logout time, extra hours, worked hours"

cur_date=$(date +%Y-%m-%d)
cur_time=""

gettimeworked()
{
	today=$(grep -r "^$cur_date" "$timefile")
	logintime="$(echo "$today" | awk '{print $2}')"
	logintime=${logintime%,}
	timeworked=$($datemathics -s "$cur_time" "$logintime")
	pauses=$(echo "$today" | awk '{print $3}')
	pauses=${pauses%,}

	echo $((timeworked - pauses))
}

showtimeworked()
{
	cur_time=$(date +%H:%M)
	worked="$(gettimeworked)"
	echo "$($datemathics -h "$worked") Hours worked"
}

loglogin()
{
	cur_time=$(date +%H:%M)
	today=$(grep -r "^$cur_date" "$timefile")

	if [ ! "$today" ]
	then
		yesterday=$(tail -n 1 "$timefile")
		y_month=${yesterday%-*}
		y_month=${y_month#*-}
		t_month=${cur_date%-*}
		t_month=${t_month#*-}
		# changed the month, append timefile to the global time file and begin a new monthly time file
		if [ "$y_month" -lt "$t_month" ]
		then
			[ -e "$fulltimefile" ] ||
				echo "$header" > "$fulltimefile"

			tail -n +2 "$timefile" >> "$fulltimefile"
			echo "$header" > "$timefile"
		fi
		echo "$cur_date, $cur_time, 0," >> "$timefile"
		echo "TRUE" > "$HOME/.working"
		timetilexit
	else
		[ -e "$HOME/.working" ] && echo "Already Logged In" && return

		loggedout="$(echo "$today" | awk '{print $4}')"
		if [ "$loggedout" ]
		then
			echo "$cur_time" > "$HOME/.working"
			getstatus
		fi
	fi
}

takebreak()
{
	echo "FALSE" > "$HOME/.working"
	date '+%H:%M' > "$HOME/.pause"
}

resumework()
{
	stopped=$(cat "$HOME/.pause")
	now=$(date +%H:%M)

	logpause "$($datemathics -s "$now" "$stopped")"
	echo TRUE > "$HOME/.working"
	rm "$HOME/.pause"
}

logpause()
{
	downtime="$1"
	if [ "$downtime" ]
	then
		today=$(grep -r "^$cur_date" "$timefile")
		todaypause=$(echo "$today" | awk '{print $3}')
		todaypause=${todaypause%,}
		totaldowntime=$((todaypause + downtime))

		loggedout="$(echo "$today" | awk '{print $4}')"
		if [ "$loggedout" ]
		then
			newline=$(echo "$today" | awk '{print $1" " $2" " '$totaldowntime'", " $4" " $5" " $6}')
		else
			newline=$(echo "$today" | awk '{print $1" " $2" " '$totaldowntime'","}')
		fi
		[ "$newline" ] &&
			sed "s/$today/$newline/g" < "$timefile" > "$timefile.aux" &&
			mv "$timefile.aux" "$timefile"
	else
		echo "ERROR: To log a pause inform pause time"
	fi
}

loglogout()
{
	if [ -e "$HOME/.working" ]
	then
		cur_time=$(date +%H:%M)
		today=$(grep -r "^$cur_date" "$timefile")
		timeworked=$(gettimeworked)

		loggedout="$(echo "$today" | awk '{print $4}')"
		if [ ! "$loggedout" ]
		then
			# compute work hours
			newline="$today $cur_time, 00:00, $("$datemathics" -h "$timeworked")"
		else
			# compute extra hours
			login="$(cat "$HOME/.working")"

			extraworked="$(echo "$today" | awk '{print $5}')"
			extraworked=${extraworked%,}
			extra="$($datemathics -s "$cur_time" "$login")"
			extra="$($datemathics -h "$extra")"
			extra="$($datemathics -a "$extra" "$extraworked")"

			totaltime="$(gettimeworked)"
			totaltime="$($datemathics -h "$totaltime")"
			totaltime="$($datemathics -a "$extra" "$totaltime")"

			newline="$(echo "$today" | awk '{print $1" " $2" " $3" " $4}') $extra, $totaltime"
		fi

		sed "s/$today/$newline/g" < "$timefile" >"$timefile.aux" &&
			mv "$timefile.aux" "$timefile"
		rm "$HOME/.working"
	else
		echo "You must be logged in to logout"
	fi
}

timetilexit()
{
	cur_time=$(date +%H:%M)
	timeworked=$(gettimeworked)
	timeleft=$(( 480 - "$timeworked"))
	weekday=$(getweekday "$cur_date")
	balance="$(getbalance)"
	balance_in_hours="$($datemathics -h "$balance")"

	if [ "$weekday" = "Sa" ] || [ "$weekday" = "Su" ]
	then
		msg="Working extra hours.\n"
		timeleft="0"
	else
		if [ "$timeleft" -lt 1 ]
		then
			msg="You're already working over hours for ${timeleft#-} minutes.\n"
		else
			hoursleft=$($datemathics -h "$timeleft")
			msg="$hoursleft left, estimated exit: $(data_hora -a "$cur_time" "$hoursleft").\n"
		fi
	fi

	if [ "$balance" -lt 0 ]
	then
		if [ "$balance" -gt "$timeleft" ]
		then
			msg="$msg""Stop working now and use $($datemathics -s "$balance_in_hours" "$hoursleft") extra hours\n"
		else
			left_minus_extra_hours="$($datemathics -s "$hoursleft" "$balance_in_hours")"
			hours_left_minus_extra="$($datemathics -h "$left_minus_extra_hours")"
			extra_use="$($datemathics -s "$hoursleft" "$hours_left_minus_extra")"
			extra_use="$($datemathics -h "$extra_use")"
			left_used_extra="$($datemathics -s "$balance_in_hours" "$extra_use")"
			left_used_extra="$($datemathics -h "$left_used_extra")"
			if [ "$left_minus_extra_hours" -lt 1 ]
			then
				msg="$msg""Stop working now and still have $hours_left_minus_extra extra hours.\n"
			else
				msg="$msg""Work only $($datemathics -h "$left_minus_extra_hours") and use $extra_use extra hours.\n"
			fi
		fi
	else
		msg="$msg""Work $($datemathics -a "$hoursleft" "$balance_in_hours") and pay the $balance_in_hours hours you owe.\n"
	fi

	[ "$1" = "notify" ] &&
		notify-send "$msg" ||
		printf "$msg"
}

getweekday()
{
	[ ! "$1" ] && return

	date="${1%,}"; shift
	day="${date##*-0}"

	cal_line="$(cal -v "$date" | grep " $day ")"

	echo "$cal_line" | awk '{print $1}'
}

getexpectedhours()
{
	[ ! "$1" ] && echo "0" && return

	expected_hours=0

	number_of_days="$1"; shift

	for line in $(tail -n "$number_of_days" "$timefile" | awk '{print $1}')
	do
		date="${line%%,*}"
		weekday=$(getweekday "$date")
		if [ ! "$weekday" = "Sa" ] && [ ! "$weekday" = "Su" ]
		then
			expected_hours=$((expected_hours + 480))
		fi
	done

	echo "$expected_hours"
}

getbalance()
{
	total="00:00"
	balance=0
	msg=""

	today=$(grep -r "^$cur_date" "$timefile")
	loggedout="$(echo "$today" | awk '{print $4}')"

	# Do not count header
	number_of_days=$(wc -l < "$timefile")
	number_of_days=$((number_of_days -1))

	# Only take into account week days, worked weekends are extra hours
	# Do not take today into account if i have not logged out
	if [ ! "$loggedout" ]
	then
		expected_n_minutes=$(getexpectedhours $((number_of_days - 1)))
		hours_worked_list="$(tail -n "$number_of_days" "$timefile" | head -n -1 | awk '{print $6}')"
	else
		expected_n_minutes=$(getexpectedhours "$number_of_days")
		hours_worked_list="$(tail -n "$number_of_days" "$timefile" | awk '{print $6}')"
	fi

	for hours in $hours_worked_list
	do
		total=$($datemathics -a "$total" "$hours")
	done

	#convert total to minutes so it's easier to operate
	total="$($datemathics -m "$total")"
	balance=$((expected_n_minutes - total))

	echo "$balance"
}

showbalance()
{
	balance="$(getbalance)"

	if [ "$balance" -lt 0 ]
	then
		# make it positive
		balance=${balance#-}
		msg="You have $($datemathics -h "$balance") extra hours"
	else
		msg="You owe $($datemathics -h "$balance") hours"
	fi

	echo "$msg"
}

showtimefile()
{
	column -s',' -t < "$timefile"
	[ "$(wc -l < "$timefile")" -lt 2 ] && return
	showbalance
}

getstatus()
{
	[ ! -e "$HOME/.working" ] && echo "Not working" && return

	status="$(cat "$HOME/.working")"
	if [ "$status" = "TRUE" ]
	then
		echo Working normal hours
	elif [ "$status" = "FALSE" ]
	then
		echo On a break
	else
		echo Working extra hours
	fi
}

# RUNNING
[ -e "$timefile" ] ||
	echo "$header" > "$timefile"

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
	edit)
		"$EDITOR" "$timefile"
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
		echo "		edit: Opens the timefile with EDITOR"
		echo "		show: Shows the timefile"
		echo "		status: Shows the working status"
		;;
esac
