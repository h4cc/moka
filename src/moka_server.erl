%%% Copyright (c) 2012, Samuel Rivas <samuelrivas@gmail.com>
%%% All rights reserved.
%%% Redistribution and use in source and binary forms, with or without
%%% modification, are permitted provided that the following conditions are met:
%%%     * Redistributions of source code must retain the above copyright
%%%       notice, this list of conditions and the following disclaimer.
%%%     * Redistributions in binary form must reproduce the above copyright
%%%       notice, this list of conditions and the following disclaimer in the
%%%       documentation and/or other materials provided with the distribution.
%%%     * Neither the name the author nor the names of its contributors may
%%%       be used to endorse or promote products derived from this software
%%%       without specific prior written permission.
%%%
%%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
%%% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
%%% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
%%% ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
%%% INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
%%% (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
%%% LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
%%% ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
%%% (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
%%% THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

%%% @copyright 2012 Samuel Rivas
%%% @doc The main moka process
%%%
%%% Each moka server handles the moking for a single module. Moka servers must
%%% be started through the {@link moka_sup}
%%%
%%% You should not use the functions provided by this module directly, use the
%%% ones in {@link moka}
-module(moka_server).
-behaviour(gen_server).

%%%_* Exports ==========================================================
-export([start_link/2, stop/1, replace/4, load/1]).

%% This function should only be used for debugging moka
-deprecated([{stop, 1}]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%%%_* Types ============================================================

-record(state, {
          module             :: module() | undefined,
          abs_code           :: moka_mod_handler:abstract_code() | undefined,
          handler_count = 0  :: non_neg_integer()
         }).

-type moka_server() :: atom().

-export_type([moka_server/0]).

%%%_* API ==============================================================

%% @doc Use {@link moka:start/2}
-spec start_link(moka_server(), module()) ->
                        {ok, pid()} | ignore | {error, term()}.
start_link(ServerName, MokedMod) ->
    gen_server:start_link({local, ServerName}, ?MODULE, MokedMod, []).

%% @doc Stops a moka server
%%
%% @deprecated don't use this function, it's only intended for debugging moka
-spec stop(moka_server()) -> ok.
stop(MokaServ) -> sel_gen_server:call(MokaServ, stop).

%% @doc Use {@link moka:replace/4}
-spec replace(moka_server(), module(), atom(), fun()) -> ok.
replace(MokaServ, Module, Function, NewBehaviour) ->
    sel_gen_server:call(MokaServ, {replace, Module, Function, NewBehaviour}).

%% @doc Use {@link moka:load/1}
-spec load(moka_server()) -> ok.
load(MokaServ) -> sel_gen_server:call(MokaServ, load).

%%%_* gen_server callbacks =============================================

%% @private
init(Mod) ->
    try
        %% needed to have terminate run before the server dies
        process_flag(trap_exit, true),
        {ok, #state{
           module = Mod,
           abs_code = moka_mod_utils:get_abs_code(Mod)
          }}
    catch
        Excpt -> {stop, {Excpt, erlang:get_stacktrace()}}
    end.

%% @private
handle_call(Request, From, State) ->
    try
        safe_handle_call(Request, From, State)
    catch
        Excpt ->
            {reply, {error, Excpt}, State};
        error:Reason ->
            Error = {Reason, erlang:get_stacktrace()},
            {stop, Error, {error, Error}, State}
    end.

%% FIXME This function is ugly, refactor
safe_handle_call({replace, Module, Function, NewBehaviour}, _From, State) ->
    {arity, Arity} = erlang:fun_info(NewBehaviour, arity),
    HandlerName = call_handler_name(State),
    moka_call_handler:start_link(HandlerName),
    moka_call_handler:set_response_fun(HandlerName, NewBehaviour),
    NewCode =
        moka_mod_utils:replace_remote_calls(
          {Module, Function, Arity},
          {moka_call_handler, get_response, [HandlerName, '$args']},
          State#state.abs_code),
    {reply, ok,
     State#state{
       handler_count = State#state.handler_count + 1,
       abs_code = NewCode}};

safe_handle_call(load, _From, State) ->
    moka_mod_utils:load_abs_code(State#state.module, State#state.abs_code),
    {reply, ok, State};

safe_handle_call(stop, _From, State) ->
    {stop, normal, ok, State};

safe_handle_call(Request, _From, _State) ->
    throw({bad_call, Request}).

%% @private
handle_cast(_Msg, State) -> {noreply, State}.

%% @private
handle_info(_Info, State) -> {noreply, State}.

%% @private
terminate(_Reason, State) ->
    moka_mod_utils:restore_module(State#state.module).

%% @private
code_change(_OldVsn, State, _Extra) -> {ok, State}.

%%%_* Private functions ================================================

call_handler_name(#state{module = Module, handler_count = N}) ->
    list_to_atom(lists:flatten(io_lib:format("~p_~p", [Module, N]))).

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 4
%%% End:
