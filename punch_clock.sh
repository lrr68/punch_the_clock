#!/bin/sh

#- POSIX compliant shell script to keep track of the time i have been working.
#- Needs another script that can add and subtract hours (00:00) and convert minutes to HH:MM.
#- This other script is provided at https://raw.githubusercontent.com/lrr68/punch_the_clock/main/date_time.sh and https://raw.githubusercontent.com/lrr68/rice/master/.local/bin/data_hora

# Script capable of doing operations with date and time
DATEMATHICS="date_time.sh"
TIMEFILE="$HOME/.time/workhours.csv"
HEADER="day, login time, pauses (in minutes), logout time, extra hours, worked hours"
DATE=$(date +%Y-%m-%d)
TIME=""

gettimeworked()
{
	TODAY=$(grep -r "^$DATE" $TIMEFILE)
	LOGINTIME=$(echo $TODAY | awk '{print $2}')
	LOGINTIME=${LOGINTIME%,}
	TIMEWORKED=$($DATEMATHICS -s $TIME $LOGINTIME)
	PAUSES=$(echo $TODAY | awk '{print $3}')
	PAUSES=${PAUSES%,}

	echo $((TIMEWORKED - PAUSES))
}

showtimeworked()
{
	TIME=$(date +%H:%M)
	WORKED=$(gettimeworked)
	echo "$($DATEMATHICS -m $WORKED) Hours worked"
}

loglogin()
{
	TIME=$(date +%H:%M)
	TODAY=$(grep -r "^$DATE" $TIMEFILE)

	if [ ! "$TODAY" ]
	then
		echo "$DATE, $TIME, 0," >> $TIMEFILE
		echo "TRUE" > $HOME/.working
	else

		[ -a $HOME/.working ] && echo "Already Logged In" && return

		LOGGEDOUT="$(echo $TODAY | awk '{print $4}')"
		if [ "$LOGGEDOUT" ]
		then
			# backup file just in case
			cp $TIMEFILE "$TIMEFILE.bkp"
			echo "$TIME" > $HOME/.working
		fi
	fi
}

takebreak()
{
	echo "FALSE" > $HOME/.working
	echo "$(date +%H:%M)" > $HOME/.pause
}

resumework()
{
	STOPPED=$(cat $HOME/.pause)
	NOW=$(date +%H:%M)

	logpause "$($DATEMATHICS -s $NOW $STOPPED)"
	echo TRUE > $HOME/.working
	rm $HOME/.pause
}

logpause()
{
	DOWNTIME="$1"
	if [ "$DOWNTIME" ]
	then
		TODAY=$(grep -r "^$DATE" $TIMEFILE)
		TODAYPAUSE=$(echo $TODAY | awk '{print $3}')
		TODAYPAUSE=${TODAYPAUSE%,}
		TOTALDOWNTIME=$((TODAYPAUSE + DOWNTIME))

		LOGGEDOUT="$(echo $TODAY | awk '{print $4}')"
		if [ "$LOGGEDOUT" ]
		then
			NEWLINE=$(echo $TODAY | awk '{print $1" " $2" " '$TOTALDOWNTIME'", " $4" " $5" " $6}')
		else
			NEWLINE=$(echo $TODAY | awk '{print $1" " $2" " '$TOTALDOWNTIME'","}')
		fi
		[ "$NEWLINE" ] &&
			sed "s/$TODAY/$NEWLINE/g" < $TIMEFILE > "$TIMEFILE.aux" &&
			mv "$TIMEFILE.aux" $TIMEFILE
	else
		echo "ERROR: To log a pause inform pause time"
	fi
}

loglogout()
{
	if [ ! -a $HOME/.working ]
	then
		TIME=$(date +%H:%M)
		TODAY=$(grep -r "^$DATE" $TIMEFILE)
		TIMEWORKED=$(gettimeworked)

		LOGGEDOUT="$(echo $TODAY | awk '{print $4}')"
		if [ ! "$LOGGEDOUT" ]
		then
			# compute work hours
			NEWLINE="$TODAY $TIME, 00:00, $($DATEMATHICS -m$TIMEWORKED)"
		else
			# compute extra hours
			[ -a $HOME/.working ] &&
			LOGIN="$(cat $HOME/.working)" ||
			echo "Not Logged in" && return

			EXTRAWORKED="$(echo $TODAY | awk '{print $5}')"
			EXTRAWORKED=${EXTRAWORKED%,}
			echo EXTRAWORKED $EXTRAWORKED
			EXTRA="$($DATEMATHICS -s $TIME $LOGIN)"
			EXTRA="$($DATEMATHICS -m $EXTRA)"
			EXTRA="$($DATEMATHICS -a $EXTRA $EXTRAWORKED)"

			TOTALTIME="$(gettimeworked)"
			TOTALTIME="$($DATEMATHICS -m $TOTALTIME)"
			echo totaltime $TOTALTIME
			TOTALTIME="$($DATEMATHICS -a $EXTRA $TOTALTIME)"

			NEWLINE="$(echo $TODAY | awk '{print $1" " $2" " $3" " $4}') $EXTRA, $TOTALTIME"
		fi

		sed "s/$TODAY/$NEWLINE/g" < $TIMEFILE >"$TIMEFILE.aux" &&
			mv "$TIMEFILE.aux" $TIMEFILE
		rm $HOME/.working
	else
		echo "You must be logged in to logout"
	fi
}

timetilexit()
{
	TIME=$(date +%H:%M)
	TIMEWORKED=$(gettimeworked)
	TIMELEFT=$(( 8*60 - $TIMEWORKED))
	if [ $TIMELEFT -lt 1 ]
	then
		MSG="You're already working over hours for ${TIMELEFT#-} minutes"
	else
		TIMELEFT=$($DATEMATHICS -m $TIMELEFT)
		MSG="$TIMELEFT left, estimated exit: $(data_hora -a $TIME $TIMELEFT)"
	fi

	case "$1" in
		notify)
			notify-send "$MSG"
			;;
		*)
			echo $MSG
			;;
	esac
}

# RUNNING
[ -a "$TIMEFILE" ] ||
	echo "$HEADER" > $TIMEFILE

case "$1" in
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
		shift
		logpause "$1"
		;;
	logout)
		loglogout
		;;
	left)
		shift
		timetilexit "$1"
		;;
	timeworked)
		showtimeworked
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
		;;
esac
