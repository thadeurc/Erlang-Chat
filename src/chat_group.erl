%% ---
%%  Excerpted from "Programming Erlang",
%%  published by The Pragmatic Bookshelf.
%%  Copyrights apply to this code. It may not be used to create training material, 
%%  courses, books, articles, and the like. Contact us if you are in doubt.
%%  We make no guarantees that this code is fit for any purpose. 
%%  Visit http://www.pragmaticprogrammer.com/titles/jaerlang for more book information.
%%---

-module(chat_group).
-import(lib_chan_mm, [send/2, controller/2]).
-import(lists, [foreach/2, reverse/2]).

-export([start/3]).

start(ServerPid, C, Nick) ->
    process_flag(trap_exit, true),
    controller(C, self()),
    send(C, ack),
    self() ! {chan, C, {relay, Nick, "I'm starting the group"}},
    group_controller(ServerPid, [{C,Nick}]).



delete(Pid, [{Pid,Nick}|T], L) -> {Nick, reverse(T, L)};
delete(Pid, [H|T], L)          -> delete(Pid, T, [H|L]);
delete(_, [], L)               -> {"????", L}.



group_controller(_ServerPid, []) ->
    exit(allGone);
group_controller(ServerPid, L) ->
    receive
	{chan, C, {relay, Nick, Str}} ->
		foreach(fun({Pid,_}) -> send(Pid, {msg,Nick,C,Str}) end, L),		
	    group_controller(ServerPid, L);
	{chan, C, {user_to_user, Nick, ToWhom, Str}} ->
		ToList = filter_list(L, ToWhom, []),
		foreach(fun({Pid, _}) -> send(Pid, {msg,Nick,C,Str}) end, [{C, Nick}] ++ ToList),
	    group_controller(ServerPid, L);
	{login, C, Nick} ->
	    controller(C, self()),
	    send(C, ack),
	    self() ! {chan, C, {relay, Nick, "I'm joining the group"}},
		L1 = [{C,Nick}|L],
		foreach(fun({Pid,_}) -> send(Pid, {new_list,L1}) end, L1),
	    group_controller(ServerPid, L1);
	{chan_closed, C} ->
	    {Nick, L1} = delete(C, L, []),
	    self() ! {chan, C, {relay, Nick, "I'm leaving the group"}},
		foreach(fun({Pid,_}) -> send(Pid, {new_list,L1}) end, L1),
	    group_controller(ServerPid, L1);
	{chan, C, {list_all, Group}} ->
		lib_chan_mm:send(ServerPid, {self(), C, list_all, Group}),
		group_controller(ServerPid, L);
	{chan, C, {list_groups}} ->
		lib_chan_mm:send(ServerPid, {self(), C, list_groups}),
		group_controller(ServerPid, L);	
	{list_groups_reply, C, Groups} ->
		send(C, {list_groups_reply, Groups}),
		group_controller(ServerPid, L);
	{list_all_reply, C, []} ->
		send(C, {group_members, L}),
		group_controller(ServerPid, L);
	{list_all_reply, C, Err} ->
		send(C, {group_members, Err}),
		group_controller(ServerPid, L);
	Any ->
	    io:format("group controller received Msg=~p~n", [Any]),
	    group_controller(ServerPid, L)
    end.

filter_list([],_,L) -> L;
filter_list([{Pid, Name}|T], ToWhom, R) when Name =:= ToWhom -> filter_list(T, ToWhom, [{Pid, Name}] ++ R);
filter_list([_H|T], ToWhom, R) -> filter_list(T, ToWhom, R).
