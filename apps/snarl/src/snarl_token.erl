-module(snarl_token).
-include("snarl.hrl").
-include_lib("riak_core/include/riak_core_vnode.hrl").

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-export([
         ping/0,
         get/1,
         add/1,
         delete/1
        ]).

-ignore_xref([ping/0]).

%% Public API

%% @doc Pings a random vnode to make sure communication is functional
ping() ->
    DocIdx = riak_core_util:chash_key({<<"ping">>, term_to_binary(now())}),
    PrefList = riak_core_apl:get_primary_apl(DocIdx, 1, snarl_token),
    [{IndexNode, _Type}] = PrefList,
    riak_core_vnode_master:sync_spawn_command(
      IndexNode, ping, snarl_token_vnode_master).

get(Token) ->
    snarl_entity_read_fsm:start(
      {snarl_token_vnode, snarl_token},
      get, Token).

add(User) ->
    Token = list_to_binary(uuid:to_string(uuid:uuid4())),
    case snarl_token:get(Token) of
        {ok, not_found} ->
            do_write(Token, add, User);
        {ok, _TokenObj} ->
            duplicate
    end.

delete(Token) ->
    do_write(Token, delete).

%%%===================================================================
%%% Internal Functions
%%%===================================================================

do_write(User, Op) ->
    snarl_entity_write_fsm:write({snarl_token_vnode, snarl_token}, User, Op).

do_write(Token, Op, Val) ->
    snarl_entity_write_fsm:write({snarl_token_vnode, snarl_token},
                                 Token, Op, Val).
