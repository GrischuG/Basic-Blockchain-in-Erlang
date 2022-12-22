# Basic-Blockchain-in-Erlang

This project was part of our fifth-semester course in the Computer Science BSc course at the Univerité de Fribourg. 
A detailed description of the implementation can be found in the report.

# How to Run

## Requirements
You need the files project.erl, color.erl and color.hrl and compile the erl files using erlang.
For the program to run, you need to start it in two terminals. The program does not run until it connects to the second instance. 

## Commands
### Compilation of Source Code
First, compile the project.erl and color.erl file in an Erlang shell with `c(project).` & `c(color).`

### Command for the Terminal

`erl -sname #{name@host} -setcookie #{secret} -s project start #{cli} #{otherName@otherHost} #{NumberofProcesses}`

- `#{name@host}` is the sname and hostname of the local erlang VM
- `#{secret}` is the shared secret
- `#{cli}` true for running in interactive (CLI) mode, false for seeing the automated 'back-end'
- `#{otherName@otherHost}` is the sname and hostname of the remote (other) erlang node
- `#{NumberofProcesses}` is the \# of processes that will mine new blocks, more -> the blockchain grows faster and the likelihood of forks increases

### Examples 
- `erl -sname foo@localhost -setcookie test -s project start true bar@localhost 3`
- `erl -sname bar@localhost -setcookie test -s project start false foo@localhost 60`

## IMPOPRTANT
The user interface currently only runs properly on windows systems.



# The MIT License (MIT)

Copyright © 2022 <Mikkeline Elleby, Marco Gabriel, Lukas Odermatt>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
