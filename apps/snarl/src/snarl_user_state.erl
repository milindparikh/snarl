%%% @author Heinz Nikolaus Gies <heinz@licenser.net>
%%% @copyright (C) 2012, Heinz Nikolaus Gies
%%% @doc
%%%
%%% @end
%%% Created : 23 Aug 2012 by Heinz Nikolaus Gies <heinz@licenser.net>

-module(snarl_user_state).

-include("snarl.hrl").

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-export([
         new/0,
         load/1,
         uuid/1, uuid/3,
         name/1, name/3,
         password/1, password/3,
         permissions/1, grant/3, revoke/3, revoke_prefix/3,
         groups/1, join/3, leave/3,
         metadata/1, set_metadata/3,
         merge/2,
         to_json/1,
         expire/2,
         gc/3,
         gcable/1
        ]).

-ignore_xref([
              new/0,
              load/1,
              uuid/1, uuid/3,
              name/1, name/3,
              password/1, password/3,
              permissions/1, grant/3, revoke/3, revoke_prefix/3,
              groups/1, join/3, leave/3,
              metadata/1, set_metadata/3,
              merge/2,
              to_json/1,
              expire/2,
              gc/3,
              gcable/1
             ]).

load(#?USER{} = User) ->
    User;

load(UserSB) ->
    Size = ?ENV(user_bucket_size, 50),
    User = statebox:value(UserSB),
    {ok, Name} = jsxd:get([<<"name">>], User),
    {ok, UUID} = jsxd:get([<<"uuid">>], User),
    Password = jsxd:get([<<"password">>], <<>>, User),
    ID0 = {{0,0,0}, load},
    Groups0 = jsxd:get([<<"groups">>], [], User),
    Permissions0 = jsxd:get([<<"permissions">>], [], User),
    Metadata = jsxd:get([<<"metadata">>], [], User),
    Groups = lists:foldl(
               fun (G, Acc) ->
                       vorsetg:add(ID0, G, Acc)
               end, vorsetg:new(Size), Groups0),
    Permissions = lists:foldl(
                    fun (G, Acc) ->
                            vorsetg:add(ID0, G, Acc)
                    end, vorsetg:new(Size), Permissions0),
    #?USER{
        uuid = vlwwregister:new(UUID),
        name = vlwwregister:new(Name),
        password = vlwwregister:new(Password),
        groups = Groups,
        permissions = Permissions,
        metadata = statebox:new(fun() -> Metadata end)
       }.

gcable(#?USER{
           permissions = Permissions,
           groups = Groups
          }) ->
    {vorsetg:gcable(Permissions), vorsetg:gcable(Groups)}.

gc(_ID,
   {Ps, Gs},
   #?USER{
       permissions = Permissions,
       groups = Groups
      } = User) ->
    Ps1 = lists:foldl(fun vorsetg:gc/2, Permissions, Ps),
    Gs1 = lists:foldl(fun vorsetg:gc/2, Groups, Gs),
    User#?USER{
            permissions = Ps1,
            groups = Gs1
           }.

new() ->
    Size = ?ENV(user_bucket_size, 50),
    #?USER{
        uuid = vlwwregister:new(<<>>),
        name = vlwwregister:new(<<>>),
        password = vlwwregister:new(<<>>),
        groups = vorsetg:new(Size),
        permissions = vorsetg:new(Size),
        metadata = statebox:new(fun jsxd:new/0)
       }.

to_json(#?USER{
            uuid = UUID,
            name = Name,
            password = Password,
            groups = Groups,
            permissions = Permissions,
            metadata = Metadata
           }) ->
    jsxd:from_list(
      [
       {<<"uuid">>, vlwwregister:value(UUID)},
       {<<"name">>, vlwwregister:value(Name)},
       {<<"password">>, vlwwregister:value(Password)},
       {<<"groups">>, vorsetg:value(Groups)},
       {<<"permissions">>, vorsetg:value(Permissions)},
       {<<"metadata">>, statebox:value(Metadata)}
      ]).

merge(#?USER{
            uuid = UUID1,
            name = Name1,
            password = Password1,
            groups = Groups1,
            permissions = Permissions1,
            metadata = Metadata1
         },
      #?USER{
          uuid = UUID2,
          name = Name2,
          password = Password2,
          groups = Groups2,
          permissions = Permissions2,
          metadata = Metadata2
         }) ->
    #?USER{
        uuid = vlwwregister:merge(UUID1, UUID2),
        name = vlwwregister:merge(Name1, Name2),
        password = vlwwregister:merge(Password1, Password2),
        groups = vorsetg:merge(Groups1, Groups2),
        permissions = vorsetg:merge(Permissions1, Permissions2),
        metadata = statebox:merge([Metadata1, Metadata2])
       }.

name(User) ->
    vlwwregister:value(User#?USER.name).

name(_, Name, User) ->
    User#?USER{
            name = vlwwregister:assign(Name, User#?USER.name)
           }.

uuid(User) ->
    vlwwregister:value(User#?USER.uuid).

uuid(_, UUID, User) ->
    User#?USER{
            uuid = vlwwregister:assign(UUID, User#?USER.uuid)
           }.

password(User) ->
    vlwwregister:value(User#?USER.password).

password(_, Password, User) ->
    Name = name(User),
    User#?USER{
            password = vlwwregister:assign(crypto:sha([Name, Password]),
                                           User#?USER.password)
           }.

permissions(User) ->
    vorsetg:value(User#?USER.permissions).

grant(ID, Permission, User) ->
    User#?USER{
            permissions =
                vorsetg:add(ID, Permission, User#?USER.permissions)
           }.


revoke(ID, Permission, User) ->
    User#?USER{
            permissions =
                vorsetg:remove(ID, Permission, User#?USER.permissions)
           }.

revoke_prefix(ID, Prefix, User) ->
    P0 = User#?USER.permissions,
    Ps = permissions(User),
    P1 = lists:foldl(fun (P, PAcc) ->
                             case lists:prefix(Prefix, P) of
                                 true ->
                                     vorsetg:remove(ID, P, PAcc);
                                 _ ->
                                     PAcc
                             end
                     end, P0, Ps),
    User#?USER{
            permissions = P1
           }.

groups(User) ->
    vorsetg:value(User#?USER.groups).


join(ID, Group, User) ->
    User#?USER{
            groups =
                vorsetg:add(ID, Group, User#?USER.groups)
           }.

leave(ID, Group, User) ->
    User#?USER{
            groups =
                vorsetg:remove(ID, Group, User#?USER.groups)
           }.

metadata(User) ->
    User#?USER.metadata.

set_metadata(Attribute, delete, User) ->
    User#?USER{
            metadata =
                statebox:modify({fun jsxd:delete/2,
                                 [Attribute]}, User#?USER.metadata)
           };

set_metadata(Attribute, Value, User) ->
    User#?USER{
            metadata =
                statebox:modify({fun jsxd:set/3,
                                 [Attribute, Value]}, User#?USER.metadata)
           }.

expire(Timeout, User) ->
    User#?USER{
            metadata =
                statebox:expire(Timeout, User#?USER.metadata)
           }.

-ifdef(TEST).

mkid() ->
    {ecrdt:timestamp_us(), test}.

to_json_test() ->
    User = new(),
    UserJ = [{<<"groups">>,[]},
             {<<"metadata">>,[]},
             {<<"name">>,<<>>},
             {<<"password">>,<<>>},
             {<<"permissions">>,[]},
             {<<"uuid">>,<<>>}],
    ?assertEqual(UserJ, to_json(User)).

name_test() ->
    Name0 = <<"Test0">>,
    User0 = new(),
    User1 = name(mkid(), Name0, User0),
    Name1 = <<"Test1">>,
    User2 = name(mkid(), Name1, User1),
    ?assertEqual(Name0, name(User1)),
    ?assertEqual(Name1, name(User2)).

password_test() ->
    Name = "Test",
    Password = "Test",
    Hash = crypto:sha([Name, Password]),
    User0 = new(),
    User1 = name(mkid(), Name, User0),
    User2 = password(mkid(), Password, User1),
    ?assertEqual(Hash, password(User2)).

permissions_test() ->
    P0 = [<<"P0">>],
    P1 = [<<"P1">>],
    User0 = new(),
    User1 = grant(mkid(), P0, User0),
    User2 = grant(mkid(), P1, User1),
    User3 = grant(mkid(), P0, User2),
    User4 = revoke(mkid(), P0, User3),
    User5 = revoke(mkid(), P1, User3),
    ?assertEqual([P0], permissions(User1)),
    ?assertEqual([P0, P1], permissions(User2)),
    ?assertEqual([P0, P1], permissions(User3)),
    ?assertEqual([P1], permissions(User4)),
    ?assertEqual([P0], permissions(User5)).

groups_test() ->
    G0 = "G0",
    G1 = "G1",
    User0 = new(),
    User1 = join(mkid(), G0, User0),
    User2 = join(mkid(), G1, User1),
    User3 = join(mkid(), G0, User2),
    User4 = leave(mkid(), G0, User3),
    User5 = leave(mkid(), G1, User3),
    ?assertEqual([G0], groups(User1)),
    ?assertEqual([G0, G1], groups(User2)),
    ?assertEqual([G0, G1], groups(User3)),
    ?assertEqual([G1], groups(User4)),
    ?assertEqual([G0], groups(User5)).

-endif.
