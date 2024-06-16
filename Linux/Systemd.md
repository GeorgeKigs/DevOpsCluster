## Systemd
Systemd is the new linux implementation of init.It handles the regular boot process as well as the major functionality of a number of standard unix services such as cron and inetd.

Systemd tracks individual tasks, processes that are associated with a service. It also keeps trak of any dependancy configurations. This gives you more power and insight into what is really happening in the system. It can also be used to manage filesystem mounts, monitor the network. Each of these system tasks is called a __unit__ while each functionality is called a __unit_type__. 

A unit is a series of instructions of certain system tasks.

### Types of units
1. Service unit: Controls service daemons that are found on the unix system. 
2. Socket Units: Contols other units.
3. Mount units: Attachments of filesystem units.
4. Target units: Groups and Control other units.

When we are booting a system, there is a unit that runs. This is a target unit that is called the `default.target`. We can visualise the dependancy graph of the units using `systemd-analyze dot`. 