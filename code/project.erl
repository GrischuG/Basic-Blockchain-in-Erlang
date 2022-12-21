-module (project).
-compile(export_all).


% When starting the network and no input arguments are given
start() ->
  print("~s", [color:red("erl -sname #{name@host} -setcookie #{secret} -s project start #{cli} #{otherName@otherHost} #{NumberofProcesses}")]).

% Main start function when input arguments are given; handles the initialisation of the blockchain network
start(Args) ->
  [UX, OtherNode, Nstring] = Args,
  print("~w~n", [atom_to_list(Nstring)]),
  N = list_to_integer(atom_to_list(Nstring)), % # of processes per node

  Genesis = genesis(), 
  print(UX, "Genesis Block: ~w~n", [Genesis]),
  print(UX, "Genesis Hash: ~w~n", [hash_block(Genesis)]),

  % SPAWN processes
  Group = deploy(UX, N, [Genesis]),
  print(UX, "Starting~n"),
  
  pingNode(OtherNode),
  
  % Get Group of other Node
  exchGroup(UX, OtherNode, Group),

  % SELECT MODE INTERACTIVE / NON-INTERACTIVE
  if 
    UX == true ->
      userInterface(UX, Group);
    true ->
      noUserInterface(Group)
  end.

% Selected when no user interface is chosen
noUserInterface(Group) ->
  timer:sleep(2000),
  send_to_mempool(Group, "Data"), % Adds this String as example data
  timer:sleep(1000),
  print("No User Iterface in Starting Process -> Staring Process Finishing!").
  
% Spawn the processes in a node
deploy(UX, N, Genesis) ->
  print("Deploying ~n"),
  % Create network (use registered names for communication)
  Group = [{X, spawn(?MODULE, main, [UX, Genesis])} || X <- lists:seq(0, N-1)],
  % previously sent init to all members
  % Return group
  Group.
 
% Pings a node until it receives pong
pingNode(Node) -> 
  Ping = net_adm:ping(Node),
  if 
    Ping == pong ->
      print("~s~n", [color:green("connected")]),
      ok;
    true ->
      receive
      after
        500 ->
          pingNode(Node)
      end
  end.

% creates two processes, whch handle the sending and receiving of the other node's Group
exchGroup(UX, OtherNode, Group) ->
  spawn(?MODULE, sendGroup, [UX, OtherNode, Group]),
  PIDrecvG = spawn(?MODULE, recvGroup, [UX, OtherNode, Group]),
  register(recvG, PIDrecvG).

% Sends the local Group to the other node/host
sendGroup(UX, Other, Group) ->
  receive
  after
    3000 ->
      {recvG, Other} ! {group, Group}
  end,
  print(UX, "~s ~s ~s~n", [color:green("sent Group to other Node"), recvG, Other]).

% Receives the process list from the other node and adds it to the local Group, also refractors the commposition of the Group variable by adding the processes' host/node as a third argument -> Group = [{present, present, new}|_]
recvGroup(UX, Other, Group) ->
  receive
    {group, OtherGroup} ->
      print(UX, "~s~n", [color:magenta("recv Group from other Node")]),

      % stitch together the two groups and add hostnames
      LocalNode = node(),
      LocalGroup = [{X, P, LocalNode} || {X, P} <- Group],
      LocalOtherGroup = [{X, P, Other} || {X, P} <- OtherGroup],
      UnionGroup = LocalGroup ++ LocalOtherGroup,

      % Initialise GC handlers (with all group members)
      [P ! {init, UnionGroup} || {_, P} <- Group],
      print(UX, "~s ~w~n", [color:green("distributed unionised Group"), UnionGroup])
  end.

% Initialising main function
main(UX, Blockchain) ->
%  wait until init is sent
  receive
    {init, Group} ->
      print(UX, "~s~n", [color:green("started main")]),
      main(UX, Blockchain, Group, [],0)
  end.

% Coordinates the blockchain process; receives the messages sent between the different blochckain processes
main(UX, Blockchain, Group, Mempool,Nonce) ->
  R = rand:uniform(50),
  X = 1, % difficulty or leading zeroes of hashes to be accepted, DON'T CHANGE THIS, unless you know what you're doing  :)
  receive
    {update, PID, Block} ->
      if 
        PID == self() -> % the received Block was made by itself -> ignore
          main(UX, Blockchain, Group, Mempool,Nonce);
        
        true -> 
          print(UX, "[~p] ~s Message received from other Process ~n ~w ~n~n",[self(), color:cyan("Update"), Block]),
          {Parent_Hash,Data,_} = Block,
          New_Hash = hash_block(Block),
          New_Hash_LZ = binary:part(New_Hash, 0, X),
          LBlock = lists:last(Blockchain),
          Hash = hash_block(LBlock),
          if 
            % check if it is valid
            % Hash of the Parent needs to be in the Block and the Block's Hash needs to have X leading Zeroes
            (Hash == Parent_Hash) and (New_Hash_LZ==<<0>>) -> 
              print(UX, "~s  ~p ~n~n", [color:green(pid_to_list(self())++" Accepted"),Data]),
              % add to the blockchain, 
              % remove content from Mempool
              {Msg, _, _, _} = Data,
              Newpool = remove_from(Msg, Mempool),
              main(UX, Blockchain ++ [Block], Group, Newpool,0);
            true ->
              print(UX, "[~p] Block with data '~p'  already present / ~s ~n~n", [self(),Data, color:red("invalid")]), % already present or invalid block, i.e., not accepted; not further distingushed here.
              main(UX, Blockchain, Group, Mempool,Nonce)
          end
      end; 
    {mempool, Msg} -> % add something to Mempool
      main(UX, Blockchain, Group, Mempool ++ [Msg],Nonce);
    {getBlkCh, Sender} -> % sends the entire Blockchain to whomever requested it
      Sender ! {blkCh, Blockchain, self()},
      main(UX, Blockchain, Group, Mempool, Nonce);
    {getGroup, Sender} -> % Sends the Group to whomever requested it
      Sender ! {retGroup, Group},
      main(UX, Blockchain, Group, Mempool, Nonce);
    {getMempool, Sender} -> % Sends the Mempool to whomever requested it
      if 
        Mempool == [] ->
          Sender ! {retMempool, "Empty"};
        true -> 
          Sender ! {retMempool, Mempool}
      end,
      main(UX, Blockchain, Group, Mempool, Nonce);
    {terminate} -> % Terminates the Blockchain
      terminateNetwork(Group),
      print("~s ~n", [color:red(pid_to_list(self())++" Terminating!")]),
      timer:sleep(500),
      init:stop()
after % The after is used to create new blocks --> after no message has been received for 50 + random(0,50) miliseconds
    50 + R ->
      if % Check if mempool ha any contents in it and take first if so
        Mempool == [] ->
          Content = "Mempool empty",
          Newpool = [];
        true ->
          [Content|Newpool] = Mempool
      end,
      % New block to calculate hash & check for leading zeroes
      Block = create_block(Blockchain, {Content, self(), length(Blockchain), Nonce}),
      New_Hash = hash_block(Block),
      New_Hash_LZ = binary:part(New_Hash, 0, X),
      if % new hash does fulfill leading zeroes
        (New_Hash_LZ==<<0>>) ->
          print(UX, "~s ~w ~n", [color:yellow(pid_to_list(self())++" Mined New Block"),Block]),
          print(UX, "~s ~w ~n", [color:yellow("New Hash: "),hash_block(Block) ]),
          [P ! {update, self(), Block} || {_, P, _} <- Group],
          [print(UX, "sent to ~p~n", [P]) || {_, P, _} <- Group],
          main(UX, Blockchain ++ [Block], Group, Newpool,0);
        true -> % new hash does not fullfill leading zeroes
          main(UX, Blockchain, Group, Mempool,Nonce+1)
      end
  end.


% Creates A first block in the chain
genesis() ->  
print("Create genesis Block ~n"),
  Parent_Hash = genesis,
  Data = {"genesis", 0, 0, 0},
  Time = {0,0,0},
  {Parent_Hash, Data, Time}.
  

% A block is of the format {Parent_Hash,Data,Time}; Data is only text in our use, however, data can be 'anything' 
create_block(Blockchain, Data) ->  
    Parent = lists:last(Blockchain),
    Parent_Hash = hash_block(Parent),
    Block = {Parent_Hash, Data, erlang:timestamp()},
    Block.


% Returns the Hash of a Block
hash_block(Block) -> 
    Hash = crypto:hash(md5, erlang:term_to_binary(Block)),
    Hash.


% Print function for multilpe use cases
print(String) ->
  print(String, []).

print(false, String) ->
  print(false, String, []);
print(true, String) ->
  print(true, String, []);
print(String, Arguments) ->
  print(false, String, Arguments).

print(true, _, _) ->
  ok;
print(false, String, Arguments) ->
  io:format(String, Arguments).


% Prints all blocks of the Blockchain nicely readable
print_blockchain(BC) -> 
  print("[~p] Blockchain: ~n",[self()]),
  print_blockchain(BC,0).

print_blockchain([],_) ->
  ok;
print_blockchain([Head|Tail],N) ->
  {PH,Data,Time} = Head,
  {Content, Miner, _, Nonce} = Data,
  print("~n"),
  print("~s ~s ~n", [color:yellow("Block #"), color:yellow(integer_to_list(N))]),
  print("~p ~s ~w ~s ~p ~s ~w~n", [Content, color:blue("Nonce:"), Nonce, color:red("Miner:"), Miner, color:green("Timestamp:"), calendar:now_to_datetime(Time)]),
  print("Parent Hash: ~w ~n", [PH]),
  print("Hash:        ~w ~n", [hash_block(Head)]),
  print_blockchain(Tail,N+1).


% Sends a Msg to Mempool, so it will get included in one of the next Blocks
send_to_mempool([{_,FirstP}|_], Msg) -> 
  FirstP ! {getGroup, self()},
  receive
    {retGroup, Group} ->
      [P ! {mempool, Msg} || {_, P, _} <- Group]
    after
    3000 ->    
      print("~s", [color:red("Time Out in send_to_Mempool! Network not responding! ~n")])
    end.


% Remove Msg from Mempool
remove_from(Msg, Mempool) -> 
  lists:delete(Msg, Mempool).


% User INterface, different option can be selected
userInterface(UX, G) ->
  print("~n~n~n"
            "===================================================~n"
            "Please enter a number from the following options: =~n"
            "=================================================== ~n"
            "    - Option '1': Enter a 'String' as Data ~n"
            "    - Option '2': Print the entire Blockchain ~n"
            "    - Option '3': Print the entire Blockchain from a specific process ~n"
            "    - Option '4': Print the Mempool of every process ~n"
            "    - Option '5': List all Blockchain processes ~n"
            "    - Option '6': Write difference in time for new block created in 'Time.csv' ~n"
            "    - Option '7': Add a faulty block to the blockchain ~n"
            "    - Option '8': Exit and Terminate Blockchain ~n~n"),
  {ok, [Data|_]} = io:fread("Please enter an Option number from the above mentioned> ", "~s"),
  print("~n Your Input is ~p, ~w ~n~n", [Data, Data]),
  case Data of
    "1" -> optionOne(G), userInterface(UX, G);
    "2" -> optionTwo(G), userInterface(UX, G);
    "3" -> optionThree(G), userInterface(UX, G);
    "4" -> optionFour(G), userInterface(UX, G);
    "5" -> optionFive(G), userInterface(UX, G);
    "6" -> optionSix(G), userInterface(UX, G);
    "7" -> optionSeven(G), userInterface(UX, G);
    "8" -> optionEight(G), print("~s ~n", [color:red("User Interface Terminating! ~n")]), init:stop();
    _ -> print("~s ~n", [color:red("Invalid input!")]), userInterface(UX, G) % 'Error' Message
  end.
  

% Add text to the mempool
optionOne(Group) ->
  Data = io:get_line('Please Enter a "String" to be stored in a Block> '),
  case Data of
    "\n" -> print("~s ~n", [color:red("Newline Character/'Enter' NOT Accepted! ~n")]);
    ""   -> print("~s ~n", [color:red("Empty Argument NOT Accepted! ~n")]);
    _    -> DataNoNl = lists:droplast(Data),
    print("~n Your Input is ~p, ~w ~n~n", [DataNoNl,DataNoNl]),
    send_to_mempool(Group, DataNoNl)
  end.


% Print the entire blockchain
optionTwo(Group) ->
  view_blockchain(Group),
  receive 
    {blkCh, B, Sender} ->
      print("[CLI:~p] Received Blockchain to print from [~p] ~n", [self(), Sender]),
      print_blockchain(B)
  after
    1000 ->    
      print("~s", [color:red("Time Out in OptionTwo! Network not responding! ~n")])
  end.


% Prints the blockchain from a specific process known to the User
optionThree(G) ->
  print("~n~nPlease choose one from the list of processes: ~n"),
  optionFive(G),
  {ok, [Input|_]} = io:fread('Please enter a PID> ', "~s"),
  P = list_to_pid(Input),
  P ! {getBlkCh, self()},
  receive 
    {blkCh, B, Sender} ->
      print("[CLI:~p] Received Blockchain to print ~s [~p] ~n", [self(), color:magenta("from"), Sender]),
      print_blockchain(B)
  after
    1000 ->    
      print("~s", [color:red("Time Out in OptionThree! Network not responding! ~n")])
  end.


% Prints the mempool of every process
optionFour([{_,FirstP}|_]) ->
  FirstP ! {getGroup, self()},
  receive
    {retGroup, Group} ->
      optionFour(Group)
    after
    1000 ->    
      print("~s", [color:red("Time Out in OptionFour! Network not responding! ~n")])
    end;
optionFour([{_,P, _}|Next]) ->
  P ! {getMempool, self()},
  receive
    {retMempool, Mempool} ->
   print("~s Mempool: ~p ~n", [color:green(pid_to_list(P)), Mempool]),
    optionFour(Next)
  after
    3000 ->    
      print("~s", [color:red("Time Out in OptionFourProcessing! Network not responding! ~n")])
    end;
optionFour([]) ->
  print("All mempools printed ~n").


% Lists all rpocesses
optionFive([{_,FirstP}|_]) ->
  FirstP ! {getGroup, self()},
  receive
    {retGroup, Group} ->
      [print("~s ~n", [color:green(pid_to_list(P))]) || {_,P,_} <- Group]
    after
    1000 ->    
      print("~s", [color:red("Time Out in OptionFive! Network not responding! ~n")])
    end.


% Writes the differenz between the creation of two blocks into a csv file
optionSix(G) ->
  recordTime(G).


% Sends an update message with a faulty bock to the network  
optionSeven([{_,FirstP}|_]) ->
  FirstP ! {getGroup, self()},
  receive
    {retGroup, Group} ->
      PHash = hash_block("Not A Parent Block"),
      R = rand:uniform(),
      FaultyBlock = {PHash,{"OptionSeven: Faulty Block",self(), R, 0}, erlang:timestamp()},
      print("Faulty Block to be inserted insert: ~n"),
      print_blockchain([FaultyBlock]),
      [P! {update, self(), FaultyBlock} || {_,P,_} <- Group]
    after
    1000 ->    
      print("~s", [color:red("Time Out in OptionSeven! Network not responding! ~n")])
    end.


% Terminates Blockchain
optionEight(G) ->
  terminate(G).


% Uses local group, i.e, the group created in this shell
terminate([{_,FirstP}|_]) -> 
 print("Sending Termination Signal to the Network ~n"),
  FirstP ! {terminate}.


% Uses Group variable after group exchange between the erlang shells --> every member of the blockchain network present
terminateNetwork(G) -> 
 print("Sending Termination Signal to the Network ~n"),
  [P ! {terminate} || {_, P, _} <- G].


% Sends a message to return the blockchain
view_blockchain([{_,FirstP}|_]) ->
  FirstP ! {getBlkCh, self()}.


% Writes the differenz between the creation of two blocks into a csv file
% Init function to setup the writing process
recordTime([{_,FirstP}|_]) ->
  {ok, Fd1} = file:open("Time.csv", [write]),
  file:write(Fd1,"Time required for Block Creation ,,,\n" ++
                  "Block Number, Difference to last Block in Seconds, Nonce from this block\n"),
  file:close(Fd1),
  {ok, Fd2} = file:open("Time.csv", [append]),
  FirstP ! {getBlkCh, self()},
  receive 
    {blkCh, [_,{_,_,FirstBlock}|Rest], _} ->
      recordTime(Fd2, FirstBlock, Rest, 1)
  after
    5000 ->    
      print("~s", [color:red("Time Out in recordTime! Network not responding! ~n")])
  end.


% For every Block in the blockchain, sends the last and current block's time to writeTime()
recordTime(Fd, LastTime, [{_,{_,_,_,Nonce},Time}|Rest], BNb) ->
  writeTime(Fd, LastTime, Time, BNb, Nonce),
  recordTime(Fd, Time, Rest, BNb+1);
recordTime(Fd, _, [], _) ->
  file:close(Fd),
  print("~s ~n", [color:green("Finished writing to 'Time.csv' .")]).


% Writes the time difference between the last and current block to the .csv file
writeTime(Fd, {LMS,LS,_}, {MS,S,_}, BNb, Nonce) ->
  Time = ((MS-LMS)*1000000)+(S-LS),
  file:write(Fd, integer_to_list(BNb)++","++integer_to_list(Time)++","++integer_to_list(Nonce)++",\n").

  


% The MIT License (MIT)

% Copyright © 2022 <Mikkeline Elleby, Marco Gabriel, Lukas Odermatt>

% Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

% The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

% THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

