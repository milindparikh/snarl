%% @doc Interface for snarl-admin commands.
-module(snarl_console).

-include("snarl.hrl").

-export([join/1,
         leave/1,
         remove/1,
         down/1,
         reip/1,
         staged_join/1,
         ringready/1]).

-export([export_user/1,
         import_user/1,
         export_group/1,
         import_group/1
        ]).

-export([add_group/1,
         delete_group/1,
         gcable_group/1,
         gc_group/1,
         join_group/1,
         leave_group/1,
         grant_group/1,
         list_group/1,
         revoke_group/1]).

-export([add_user/1,
         gc_user/1,
         gcable_user/1,
         delete_user/1,
         list_user/1,
         grant_user/1,
         revoke_user/1,
         passwd/1]).

-ignore_xref([
              join/1,
              leave/1,
              gcable_user/1,
              gcable_group/1,
              delete_user/1,
              delete_group/1,
              remove/1,
              export_user/1,
              import_user/1,
              export_group/1,
              import_group/1,
              down/1,
              reip/1,
              staged_join/1,
              ringready/1,
              list_user/1,
              list_group/1,
              add_user/1,
              add_group/1,
              join_group/1,
              leave_group/1,
              grant_group/1,
              grant_user/1,
              revoke_user/1,
              revoke_group/1,
              passwd/1,
              gc_group/1,
              gc_user/1
             ]).

list_user([]) ->
    {ok, Users} = snarl_user:list(),
    io:format("UUID                                 Name~n"),
    io:format("------------------------------------ ---------------~n", []),
    lists:map(fun(UUID) ->
                      {ok, User} = snarl_user:get(UUID),
                      io:format("~36s ~-15s~n",
                                [UUID, jsxd:get(<<"name">>, <<"-">>, User)])
              end, Users),
    ok.
list_group([]) ->
    {ok, Users} = snarl_group:list(),
    io:format("UUID                                 Name~n"),
    io:format("------------------------------------ ---------------~n", []),
    lists:map(fun(UUID) ->
                      {ok, User} = snarl_group:get(UUID),
                      io:format("~36s ~-15s~n",
                                [UUID, jsxd:get(<<"name">>, <<"-">>, User)])
              end, Users),
    ok.


gc_group(<<"all">>, Timeout) ->
    {ok, UUIDs} = snarl_group:list(),
    {Cnt, GCed, Size} =
        lists:foldl(fun (UUID, {Cnt, GCed, Size}) ->
                            case snarl_group:gcable(UUID) of
                                {ok, A} ->
                                    MinAge = ecrdt:timestamp_us() - Timeout,
                                    A1 = [E || {{T,_},_} = E <- A, T < MinAge],
                                    case A1 of
                                        [] ->
                                            {Cnt + 1, GCed, Size};
                                        _ ->
                                            {ok, Size1} =
                                                snarl_group:gc(UUID, A1),
                                            {Cnt + 1, GCed + 1, Size + Size1}
                                    end;
                                _ ->
                                    {Cnt + 1, GCed, Size}
                            end
                    end, {0, 0, 0}, UUIDs),
    io:format("Checked ~p objects, GCed ~p of them for a total of ~p bytes.~n",
              [Cnt, GCed, Size]),
    ok;

gc_group(UUID, Timeout) ->
    case snarl_group:gcable(UUID) of
        {ok, A} ->
            MinAge = ecrdt:timestamp_us() - Timeout,
            A1 = [E || {{T,_},_} = E <- A, T < MinAge],
            {ok, Size} = snarl_group:gc(UUID, A1),
            io:format("GC ~p bytes of memory.~n", [Size]),
            ok;
        _ ->
            error
    end.

gc_group([UUID]) ->
    {Time, Unit} = ?ENV(group_sync_timeout, {1, week}),
    gc_group(list_to_binary(UUID), time_to_us(Time, atom_to_list(Unit)));

gc_group([UUID, Secs]) ->
    gc_group(list_to_binary(UUID), time_to_us(list_to_integer(Secs), "s"));

gc_group([UUID, Time, Unit]) ->
    gc_group(list_to_binary(UUID), time_to_us(list_to_integer(Time), Unit)).

gc_user(<<"all">>, Timeout) ->
    {ok, UUIDs} = snarl_user:list(),
    {Cnt, GCed, Size} =
        lists:foldl(fun (UUID, {Cnt, GCed, Size}) ->
                            case snarl_user:gcable(UUID) of
                                {ok, {A, B}} ->
                                    MinAge = ecrdt:timestamp_us() - Timeout,
                                    A1 = [E || {{T,_},_} = E <- A, T < MinAge],
                                    B1 = [E || {{T,_},_} = E <- B, T < MinAge],
                                    case {A1, B1} of
                                        {[], []} ->
                                            {Cnt + 1, GCed, Size};
                                        _ ->
                                            {ok, Size1} =
                                                snarl_user:gc(UUID, {A1, B1}),
                                            {Cnt + 1, GCed + 1, Size + Size1}
                                    end;
                                _ ->
                                    {Cnt + 1, GCed, Size}
                            end
                    end, {0, 0, 0}, UUIDs),
    io:format("Checked ~p objects, GCed ~p of them for a total of ~p bytes.~n",
              [Cnt, GCed, Size]),
    ok;

gc_user(UUID, Timeout) ->
    case snarl_user:gcable(UUID) of
        {ok, {A, B}} ->
            MinAge = ecrdt:timestamp_us() - Timeout,
            A1 = [E || {{T,_},_} = E <- A, T < MinAge],
            B1 = [E || {{T,_},_} = E <- B, T < MinAge],
            {ok, Size} = snarl_user:gc(UUID, {A1, B1}),
            io:format("GC ~p bytes of memory.~n", [Size]),
            ok;
        _ ->
            error
    end.


gc_user([UUID]) ->
    {Time, Unit} = ?ENV(user_sync_timeout, {1, week}),
    gc_user(list_to_binary(UUID), time_to_us(Time, atom_to_list(Unit)));

gc_user([UUID, Secs]) ->
    gc_user(list_to_binary(UUID), time_to_us(list_to_integer(Secs), "s"));

gc_user([UUID, Time, Unit]) ->
    gc_user(list_to_binary(UUID), time_to_us(list_to_integer(Time), Unit)).

time_to_us(Time, [$s | _]) ->
    Time * ?SECOND;
time_to_us(Time, [$m | _]) ->
    Time * ?MINUTE;
time_to_us(Time, [$h | _]) ->
    Time * ?HOUER;
time_to_us(Time, [$d | _]) ->
    Time * ?DAY;
time_to_us(Time, [$w | _]) ->
    Time * ?WEEK.

gcable_user([UUID]) ->
    case snarl_user:gcable(list_to_binary(UUID)) of
        {ok, {A, B}} ->
            io:format("GCable buckets: ~p~n", [length(A) + length(B)]),
            ok;
        _ ->
            error
    end.

gcable_group([UUID]) ->
    case snarl_group:gcable(list_to_binary(UUID)) of
        {ok, A} ->
            io:format("GCable buckets ~p~n", [length(A)]),
            ok;
        _ ->
            error
    end.

delete_user([User]) ->
    snarl_user:delete(list_to_binary(User)),
    ok.

delete_group([User]) ->
    snarl_user:delete(list_to_binary(User)),
    ok.

add_user([User]) ->
    case snarl_user:add(list_to_binary(User)) of
        {ok, UUID} ->
            io:format("User '~s' added with id '~s'.~n", [User, UUID]),
            ok;
        duplicate ->
            io:format("User '~s' already exists.~n", [User]),
            error
    end.

export_user([UUID]) ->
    case snarl_user:get(list_to_binary(UUID)) of
        {ok, UserObj} ->
            io:format("~s~n", [jsx:encode(jsxd:update(<<"password">>, fun base64:encode/1, UserObj))]),
            ok;
        _ ->
            error
    end.

import_user([File]) ->
    case file:read_file(File) of
        {error,enoent} ->
            io:format("That file does not exist or is not an absolute path.~n"),
            error;
        {ok, B} ->
            JSON = jsx:decode(B),
            JSX = jsxd:from_list(JSON),
            UUID = case jsxd:get([<<"uuid">>], JSX) of
                       {ok, U} ->
                           U;
                       undefined ->
                           list_to_binary(uuid:to_string(uuid:uuid4()))
                   end,
            As = jsxd:thread([{set, [<<"uuid">>], UUID},
                              {update, [<<"password">>],  fun base64:decode/1}],
                             JSX),
            snarl_user:import(UUID, statebox:new(fun() -> As end))
    end.


export_group([UUID]) ->
    case snarl_group:get(list_to_binary(UUID)) of
        {ok, GroupObj} ->
            io:format("~s~n", [jsx:encode(GroupObj)]),
            ok;
        _ ->
            error
    end.

import_group([File]) ->
    case file:read_file(File) of
        {error,enoent} ->
            io:format("That file does not exist or is not an absolute path.~n"),
            error;
        {ok, B} ->
            JSON = jsx:decode(B),
            JSX = jsxd:from_list(JSON),
            UUID = case jsxd:get([<<"uuid">>], JSX) of
                       {ok, U} ->
                           U;
                       undefined ->
                           list_to_binary(uuid:to_string(uuid:uuid4()))
                   end,
            As = jsxd:thread([{set, [<<"uuid">>], UUID}], JSX),
            snarl_group:import(UUID, statebox:new(fun() -> As end))
    end.

add_group([Group]) ->
    case snarl_group:add(list_to_binary(Group)) of
        {ok, UUID} ->
            io:format("Group '~s' added with id '~s'.~n", [Group, UUID]),
            ok;
        duplicate ->
            io:format("Group '~s' already exists.~n", [Group]),
            error
    end.

join_group([User, Group]) ->
    case snarl_user:lookup(list_to_binary(User)) of
        {ok, UserObj} ->
            case snarl_group:lookup(list_to_binary(Group)) of
                {ok, GroupObj} ->
                    ok = snarl_user:join(jsxd:get(<<"uuid">>, <<>>, UserObj),
                                         jsxd:get(<<"uuid">>, <<>>, GroupObj)),
                    io:format("User '~s' added to group '~s'.~n", [User, Group]),
                    ok;
                _ ->
                    io:format("Group does not exist.~n"),
                    error
            end;
        _ ->
            io:format("User does not exist.~n"),
            error
    end.

leave_group([User, Group]) ->
    case snarl_user:lookup(list_to_binary(User)) of
        {ok, UserObj} ->
            case snarl_group:lookup(list_to_binary(Group)) of
                {ok, GroupObj} ->
                    ok = snarl_user:leave(jsxd:get(<<"uuid">>, <<>>, UserObj),
                                          jsxd:get(<<"uuid">>, <<>>, GroupObj)),
                    io:format("User '~s' removed from group '~s'.~n", [User, Group]),
                    ok;
                _ ->
                    io:format("Group does not exist.~n"),
                    error
            end;
        _ ->
            io:format("User does not exist.~n"),
            error
    end.

passwd([User, Pass]) ->
    case snarl_user:lookup(list_to_binary(User)) of
        {ok, UserObj} ->
            case snarl_user:passwd(jsxd:get(<<"uuid">>, <<>>, UserObj), list_to_binary(Pass)) of
                ok ->
                    io:format("Password successfully changed for user '~s'.~n", [User]),
                    ok;
                not_found ->
                    io:format("User '~s' not found.~n", [User]),
                    error
            end;
        _ ->
            io:format("User does not exist.~n"),
            error
    end.

grant_group([Group | P]) ->
    case snarl_group:lookup(list_to_binary(Group)) of
        {ok, GroupObj} ->
            case snarl_group:grant(jsxd:get(<<"uuid">>, <<>>, GroupObj), build_permission(P)) of
                ok ->
                    io:format("Granted.~n", []),
                    ok;
                _ ->
                    io:format("Failed.~n", []),
                    error
            end;
        not_found ->
            io:format("Group '~s' not found.~n", [Group]),
            error
    end.

grant_user([User | P ]) ->
    case snarl_user:lookup(list_to_binary(User)) of
        {ok, UserObj} ->
            case snarl_user:grant(jsxd:get(<<"uuid">>, <<>>, UserObj), build_permission(P)) of
                ok ->
                    io:format("Granted.~n", []),
                    ok;
                not_found ->
                    io:format("User '~s' not found.~n", [User]),
                    error
            end;
        _ ->
            io:format("User does not exist.~n"),
            error
    end.

revoke_user([User | P ]) ->
    case snarl_user:lookup(list_to_binary(User)) of
        {ok, UserObj} ->
            case snarl_user:revoke(jsxd:get(<<"uuid">>, <<>>, UserObj), build_permission(P)) of
                ok ->
                    io:format("Granted.~n", []),
                    ok;
                not_found ->
                    io:format("User '~s' not found.~n", [User]),
                    error
            end;
        _ ->
            io:format("User does not exist.~n"),
            error
    end.

revoke_group([Group | P]) ->
    case snarl_group:lookup(list_to_binary(Group)) of
        {ok, GroupObj} ->
            case snarl_group:revoke(jsxd:get(<<"uuid">>, <<>>, GroupObj), build_permission(P)) of
                ok ->
                    io:format("Revoked.~n", []),
                    ok;
                _ ->
                    io:format("Failed.~n", []),
                    error
            end;
        not_found ->
            io:format("Group '~s' not found.~n", [Group]),
            error
    end.

join([NodeStr]) ->
    join(NodeStr, fun riak_core:join/1,
         "Sent join request to ~s~n", [NodeStr]).

staged_join([NodeStr]) ->
    Node = list_to_atom(NodeStr),
    join(NodeStr, fun riak_core:staged_join/1,
         "Success: staged join request for ~p to ~p~n", [node(), Node]).

join(NodeStr, JoinFn, SuccessFmt, SuccessArgs) ->
    try
        case JoinFn(NodeStr) of
            ok ->
                io:format(SuccessFmt, SuccessArgs),
                ok;
            {error, not_reachable} ->
                io:format("Node ~s is not reachable!~n", [NodeStr]),
                error;
            {error, different_ring_sizes} ->
                io:format("Failed: ~s has a different ring_creation_size~n",
                          [NodeStr]),
                error;
            {error, unable_to_get_join_ring} ->
                io:format("Failed: Unable to get ring from ~s~n", [NodeStr]),
                error;
            {error, not_single_node} ->
                io:format("Failed: This node is already a member of a "
                          "cluster~n"),
                error;
            {error, self_join} ->
                io:format("Failed: This node cannot join itself in a "
                          "cluster~n"),
                error;
            {error, _} ->
                io:format("Join failed. Try again in a few moments.~n", []),
                error
        end
    catch
        Exception:Reason ->
            lager:error("Join failed ~p:~p", [Exception, Reason]),
            io:format("Join failed, see log for details~n"),
            error
    end.

leave([]) ->
    try
        case riak_core:leave() of
            ok ->
                io:format("Success: ~p will shutdown after handing off "
                          "its data~n", [node()]),
                ok;
            {error, already_leaving} ->
                io:format("~p is already in the process of leaving the "
                          "cluster.~n", [node()]),
                ok;
            {error, not_member} ->
                io:format("Failed: ~p is not a member of the cluster.~n",
                          [node()]),
                error;
            {error, only_member} ->
                io:format("Failed: ~p is the only member.~n", [node()]),
                error
        end
    catch
        Exception:Reason ->
            lager:error("Leave failed ~p:~p", [Exception, Reason]),
            io:format("Leave failed, see log for details~n"),
            error
    end.

remove([Node]) ->
    try
        case riak_core:remove(list_to_atom(Node)) of
            ok ->
                io:format("Success: ~p removed from the cluster~n", [Node]),
                ok;
            {error, not_member} ->
                io:format("Failed: ~p is not a member of the cluster.~n",
                          [Node]),
                error;
            {error, only_member} ->
                io:format("Failed: ~p is the only member.~n", [Node]),
                error
        end
    catch
        Exception:Reason ->
            lager:error("Remove failed ~p:~p", [Exception, Reason]),
            io:format("Remove failed, see log for details~n"),
            error
    end.

down([Node]) ->
    try
        case riak_core:down(list_to_atom(Node)) of
            ok ->
                io:format("Success: ~p marked as down~n", [Node]),
                ok;
            {error, legacy_mode} ->
                io:format("Cluster is currently in legacy mode~n"),
                ok;
            {error, is_up} ->
                io:format("Failed: ~s is up~n", [Node]),
                error;
            {error, not_member} ->
                io:format("Failed: ~p is not a member of the cluster.~n",
                          [Node]),
                error;
            {error, only_member} ->
                io:format("Failed: ~p is the only member.~n", [Node]),
                error
        end
    catch
        Exception:Reason ->
            lager:error("Down failed ~p:~p", [Exception, Reason]),
            io:format("Down failed, see log for details~n"),
            error
    end.

reip([OldNode, NewNode]) ->
    try
        %% reip is called when node is down (so riak_core_ring_manager is not running),
        %% so it has to use the basic ring operations.
        %%
        %% Do *not* convert to use riak_core_ring_manager:ring_trans.
        %%
        application:load(riak_core),
        RingStateDir = app_helper:get_env(riak_core, ring_state_dir),
        {ok, RingFile} = riak_core_ring_manager:find_latest_ringfile(),
        BackupFN = filename:join([RingStateDir, filename:basename(RingFile)++".BAK"]),
        {ok, _} = file:copy(RingFile, BackupFN),
        io:format("Backed up existing ring file to ~p~n", [BackupFN]),
        Ring = riak_core_ring_manager:read_ringfile(RingFile),
        NewRing = riak_core_ring:rename_node(Ring, OldNode, NewNode),
        riak_core_ring_manager:do_write_ringfile(NewRing),
        io:format("New ring file written to ~p~n",
                  [element(2, riak_core_ring_manager:find_latest_ringfile())])
    catch
        Exception:Reason ->
            lager:error("Reip failed ~p:~p", [Exception,
                                              Reason]),
            io:format("Reip failed, see log for details~n"),
            error
    end.

-spec(ringready([]) -> ok | error).
ringready([]) ->
    try riak_core_status:ringready() of
        {ok, Nodes} ->
            io:format("TRUE All nodes agree on the ring ~p\n", [Nodes]);
        {error, {different_owners, N1, N2}} ->
            io:format("FALSE Node ~p and ~p list different partition owners\n",
                      [N1, N2]),
            error;
        {error, {nodes_down, Down}} ->
            io:format("FALSE ~p down.  All nodes need to be up to check.\n",
                      [Down]),
            error
    catch
        Exception:Reason ->
            lager:error("Ringready failed ~p:~p", [Exception, Reason]),
            io:format("Ringready failed, see log for details~n"),
            error
    end.


build_permission(P) ->
    lists:map(fun list_to_binary/1, P).
