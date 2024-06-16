# Time
Time on a linux machine is always based on the real-time-clock.

<!-- What is the real time clock -->

<!-- how to synchronise rtc with the kernel's time -->

Linux kernel also keeps its time. Worse than the due to time drift. Time drift is defined as the difference between the time within the kernel and the true time.

While adjusting time try and avoid using the hwclock command. But we should use the adjtimex

The kernel represents time in the form of seconds since 00:00 January 1st 1970. To get this time. we should use: `date +%s`.

The local timezone is normally controlled by `/etc/localtime`


Network time.

If your machine is connected to the internet permanently, there is a daemon that runs within _systemd_ and it is known as _timesyncd_. The protocol is known as the __Network Time Protocol__. 

Timesyncd is normally enabled by default. To see the manual page of timesyncd you can use the following command `man timesyncd.conf`. To adjust the ntp configurations manually you can use the following command.

```sh
    hwclock --syshtoc --utc
```


## Setting up recurring jobs.

### Crontabs

There are two ways to set up a recurring task within linux. They are cronjobs and timer units. Cronjobs is the default way of setting up recurring jobs but just like most processes, systemd has its own process that run the scheduled tasks. These are the timer units.

Cron jobs can be set up to run any program. It is critical in running maintenance tasks such as the log rotation.

You can use the command `crontab` to set up a cronjob. Cronjobs follow the structure shown below.

```sh
    * * * * *  [Command]
```

The file asterix represent: minute, hour, day_of_month, month, day_of_week.


We can also specify multiple fields in our options all we need to do is seperate the values with a comma.

``` sh
    15 10 5,14 * * [command]
```
The cron experssion shows the command should run on 10:15 on the 5th and 14th of every month irregadless of the week.

All the users have crontab files were they are all stored within the `/var/spool/cron/crontabs/` directory. Only sudo users can edit this directory.

For a normal user they can use this commands instead:
```sh
    # to install a crontab file:
    crontab [file]

    #  To edit crontabs
    crontab -e

    # To list all the crontabs
    crontab -l

    # To remove a crontab
    crontab -r
```

For system level tasks, you could edit the crontabs within the  `/etc/crontab file`. Key thing to note is that the formart is different as indicated below.
```sh
    * * * * * root ls > /dev/null
```

Key thing to note is that we specify the user that will be used to run the task.



### Timer Jobs
man command: `man systemd.time`

An alternative to the jobs that are currently run within the crontabs, we can use the timer jobs within our application. To set up a timer unit we need to create two units within our application. The files should be created within the `/etc/systemd/system` directory.

1. Service units
2. Timer units

#### Timer Unit
Here is an example: `loggertest.timer`

```sh
    [Unit]
    Description=Example timer unit
    [Timer]
    OnCalendar=*-*-* *:*
    Unit=loggertest.service

    [Install]
    WantedBy=timers.target 
```


The OnCalendar represents the time syntax that we will be using within the application. The * is a wildcard, simlar to what we use within the cronjob applications.

#### Service Units
This is a normal service file as illustrated in the systemd service file. A good example is:
```
    [Unit]
    Description=Example Service File
    [Service]
    Type=Oneshot
    ExecStart=ls > /dev/null
```

The file should be created within the same folder as the timer unit: `/etc/systemd/services`.
One thing to consider is that a service file that is started by timer unit can have more than one __execstart__ section. If you want more granularity you can use the the `Wants` and `Before` dependancy directives.

One thing to note is that timer jobs provide superior tracking of the tasks and units within an application.


One critical point to note is that timer units tend to run as the root user. You can specify which user you want the unit to run as by using the `system-run` command and specifing the `--user` option.

## Setting up On-Time Tasks
We can setup a one time task using the `at` command. The syntax that is used while setting up the timer is _HH:MM DD.MM.YY_. As we enter the `at` command we use it as follows: 
```sh
    at 10:20
```

To view scheduled jobs we can use the `atq` command. If you want to remove a job we should use the `atrm` command