%% ---
%%  Excerpted from "Programming Erlang",
%%  published by The Pragmatic Bookshelf.
%%  Copyrights apply to this code. It may not be used to create training material, 
%%  courses, books, articles, and the like. Contact us if you are in doubt.
%%  We make no guarantees that this code is fit for any purpose. 
%%  Visit http://www.pragmaticprogrammer.com/titles/jaerlang for more book information.
%%---
-module(chat_client).

-import(io_widget, 
	[get_state/1, insert_str/2, set_prompt/2, set_state/2, 
	 set_title/2, set_handler/2, update_state/3]).

-export([start/0, test/0, connect/5]).


start() -> 
    connect("localhost", 2223, "AsDT67aQ", "general", "joe").


test() ->
    connect("localhost", 2223, "AsDT67aQ", "general", "joe"),
    connect("localhost", 2223, "AsDT67aQ", "general2", "jane"),
    connect("localhost", 2223, "AsDT67aQ", "general2", "jim"),
    connect("localhost", 2223, "AsDT67aQ", "general", "sue").
	   

connect(Host, Port, HostPsw, Group, Nick) ->
    spawn(fun() -> handler(Host, Port, HostPsw, Group, Nick) end).
				 
handler(Host, Port, HostPsw, Group, Nick) ->
    process_flag(trap_exit, true),
    Widget = io_widget:start(self()),
    set_title(Widget, Nick),
    set_state(Widget, Nick),
    set_prompt(Widget, [Nick, " > "]),
    set_handler(Widget, fun parse_command/1),
    start_connector(Host, Port, HostPsw),    
    disconnected(Widget, Group, Nick).



disconnected(Widget, Group, Nick) ->
    receive
	{connected, MM} ->
	    insert_str(Widget, "connected to server\nsending data\n"),
	    lib_chan_mm:send(MM, {login, Group, Nick}),
	    wait_login_response(Widget, MM, Group);
	{Widget, destroyed} ->
	    exit(died);
	{status, S} ->
	    insert_str(Widget, to_str(S)),
	    disconnected(Widget, Group, Nick);
	Other ->
	    io:format("chat_client disconnected unexpected:~p~n",[Other]),
	    disconnected(Widget, Group, Nick)
    end.



wait_login_response(Widget, MM, Group) ->
    receive
	{chan, MM, ack} ->
	    active(Widget, MM, Group);
	Other ->
	    io:format("chat_client login unexpected:~p~n",[Other]),
	    wait_login_response(Widget, MM, Group)
    end. 



active(Widget, MM, Group) ->
     receive
	 {Widget, Nick, Str} ->	
		 case is_user_to_user_msg(Str) of
			 true -> 
				 {ToWhom, Msg} = parseOneToOneMsg(Str),
				 lib_chan_mm:send(MM, {user_to_user, Nick, ToWhom, Msg});
		 	 false -> 
				 lib_chan_mm:send(MM, {relay, Nick, Str})
		 end,
		 active(Widget, MM, Group);
	 {chan, MM, {msg, From, Pid, Str}} ->
	     insert_str(Widget, ["(",Group, ")", From,"@",pid_to_list(Pid)," ", Str, "\n"]),
		 validate_input(Str, MM, Group),
	     active(Widget, MM, Group);
	 {chan, MM, {group_members, L}} ->
		 T = [names(X) || X <- L],
		 insert_str(Widget, ["(",Group, ") members: " ++ T, "\n"]),
		 active(Widget, MM, Group);
	{chan, MM, {list_groups_reply, L}} ->
		 T = [groups(X) || X <- L],
		 insert_str(Widget, ["Groups: " ++ T, "\n"]),
		 active(Widget, MM, Group);
	 {'EXIT',Widget,windowDestroyed} ->
	     lib_chan_mm:close(MM);
	 {close, MM} ->
	     exit(serverDied);
	 Other ->
	     io:format("chat_client active unexpected:~p~n",[Other]),
	     active(Widget, MM, Group)
     end. 

names({_, Name}) ->
	["\n\t",Name].

groups({Name, _}) ->
	["\n\t", Name].


validate_input(Str, MM, Group) ->
	case string:str(Str, "show_group_members") > 0 of
		true ->
			NGroup = get_group_name(Str),
			case NGroup =:= undefined of
				true ->lib_chan_mm:send(MM, {list_all,Group});
				false ->lib_chan_mm:send(MM, {list_all,NGroup})
			end,
			true;	
		false ->
			case string:str(Str, "show_groups") > 0 of  
				true -> 
					lib_chan_mm:send(MM, {list_groups}),
					true;
				false -> 
					false
			end
	end.

	
start_connector(Host, Port, Pwd) ->
    S = self(),
    spawn_link(fun() -> try_to_connect(S, Host, Port, Pwd) end).
    
try_to_connect(Parent, Host, Port, Pwd) ->
    %% Parent is the Pid of the process that spawned this process
    case lib_chan:connect(Host, Port, chat, Pwd, []) of
	{error, _Why} ->
	    Parent ! {status, {cannot, connect, Host, Port}},
	    sleep(2000),
	    try_to_connect(Parent, Host, Port, Pwd);
	{ok, MM} ->
	    lib_chan_mm:controller(MM, Parent),
	    Parent ! {connected, MM},
	    exit(connectorFinished)
    end.


sleep(T) ->
    receive
    after T -> true
    end.
	    
to_str(Term) ->
    io_lib:format("~p~n",[Term]).

parse_command(Str) -> skip_to_gt(Str).

skip_to_gt(">" ++ T) -> T;
skip_to_gt([_|T])    -> skip_to_gt(T);
skip_to_gt([])       -> exit("no >").

is_user_to_user_msg(Str) ->
	{match, L} = regexp:matches(Str, "\s*to:\s*[a-zA-Z_][0-9a-zA-Z_]+\s*!.*"),
	length(L) > 0.

get_group_name(Str) ->
	Pos = string:str(Str, ":"),
	case Pos > 0 of
		false -> undefined;
		true -> string:strip(string:sub_string(Str, Pos + 1))
	end.


%% expected Str in format to:<user> ! message.
%% e.g: to:jow ! Hi Man!
parseOneToOneMsg(Str) ->
	CleanStr = string:strip(Str),
	BeginWho = string:str(CleanStr, "to:") + 3,
	EndWho = string:str(CleanStr, "!") - 1,
	WhoStr = string:strip(string:sub_string(CleanStr, BeginWho, EndWho)),
	Msg = string:strip(string:sub_string(CleanStr, EndWho + 2)),
	{WhoStr, Msg}.

	
	