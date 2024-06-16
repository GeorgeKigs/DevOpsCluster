# Tracking Processes


<!-- ! check out the man pages for ps and top -->
We track processes using the `ps` command. This provides users with the current system status. To enhance this we can use the `top` command. It provides us with an interactive enviroment that updates after every three seconds. We can also sort and filter the processes running by sending key strokes to the terminal.


Here are the most commonly used keystrokes within the process.

| Key |Action|
|---|---|
| Spacebar | Updates the display immediately |
| M | Sorts by current resident memory usage |
| T | Sorts by total (cumulative) CPU usage |
| P | Sorts by current CPU usage (the default) |
| u | Displays only one user’s processes |
| f | Selects different statistics to display |
| ? | Displays a usage summary for all top commands |

## lsof
The command lsof is used to check which filesystems are running and the processes that are using thos files.

The output of the command looks as follows:
|Heading | Meaning|
|---|---|
| COMMAND | The command name for the process that holds the file descriptor. |
| PID | The process ID. |
| USER | The user running the process. |
| FD | This field can contain two kinds of elements. In most of the preceding output|
| FD | column shows the purpose of the file. |
| TYPE | The file type (regular file, directory, socket, and so on). |
| DEVICE | The major and minor number of the device that holds the file. |
| SIZE | The file’s size. |
| NODE | The file’s inode number. |
| NAME | The filename. |

The infomation that we get from lsof can be a bit overwhelming. We can get the desired results by using the following commands:

```sh
    lsof +D /usr 
    # Used to display all the files and subdirectories and the running processes using these files.

    # To track the resources that are using a particular pid
    lsof -p pid
```

## strace
Strace is used to trace system calls that are made within the kernel. Its is relatively useful when you want to debug a failing process.
For us to check and see which commands are running we need to append the -o option that sends the output to a particlar file. We can also redirect the output to a file as shown in the file below.
```sh
    strace cat /dev/null 2> output.txt
```
Some key points to note.

## ltrace
ltrace is used track the system libraries that are called when process is running. Please noe that it will produce an overwhelming amount of information.

It is more suitable to filter out the process using built in commands used within the command line.
