# Basic-Blockchain-in-Erlang

This project was part of our fifth-semester course in the Computer Science course at the Univerité de Fribourg. 

# How to Run

## Requirements
You need the files \textit{project.erl}, \textit{color.erl} and \textit{color.hrl} and compile the erl files using erlang.
For the program to run, you need to start it in two terminals. The program does not run until it connects to the second instance. 

## Commands
erl -sname \#\{name@host\} -setcookie \#\{secret\} -s project start \#\{cli\} \newline \#\{otherName@otherHost\} \#\{NumberofProcesses\}

- \#\{name@host\} is the sname and hostname of the local erlang VM
- \#\{secret\} is the shared secret
- \#\{cli\} true for running in interactive (CLI) mode, false for seeing the automated 'back-end'
- \#\{otherName@otherHost\} is the sname and hostname of the remote (other) erlang node
- \#\{NumberofProcesses\} is the \# of processes that will mine new blocks, more = the blockchain grows faster and the likelihood of forks increases

## Examples 
- erl -sname foo@localhost -setcookie test -s project start true bar@localhost 3
- erl -sname bar@localhost -setcookie test -s project start false foo@localhost 60

##IMPOPRTANT
The user interface currently only runs properly on windows systems.
asdasd
