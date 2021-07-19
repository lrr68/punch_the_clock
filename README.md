# punch_the_clock
Shell script for keeping track of work hours.
Stores date, login time, time on breaks, logout time, extra hours worked and total time worked in a csv file specified by $TIMEFILE.
Set this variable in the script accordingly to your preferences.

## Usage
```
punch_clock ( command )
```
### commands:
# login
Register the login time and sets status as working. If you login after having already logged out it will register the time until you call logout as you worked as extra hours.

# logpause <time in minutes>
Register a pause of X minutes where X is the time informed. This command is usefull if you want to register a pause without using the break and resume commands. Also, the resume command uses this command.

# logout
Register the logout time and removes the working status.

# break
Register the time you start taking a break.

# resume
Remove the break status and register the time you have been out.

# left [ notify ]
Informs time left for you to complete 8 hours of work. If ```notify``` is passed as argument, it will use notify send to inform the time.

## Examples
```
punch_clock login;
# work
punch_clock logout;
```

```
# working
punch_clock logpause 15; #logs a pause of 15 minutes
```

```
punch_clock break;
# on a break
punch_clock resume;
# pause logged
```

```
# working
punch_clock left;
04:20 left
```
