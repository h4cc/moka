%%% @doc Unit tests for {@link moka_mod_utils}

-module(moka_mod_utils_eunit).

-include_lib("eunit/include/eunit.hrl").

get_beam_code_test_() ->
    [?_assert(is_binary(moka_mod_utils:get_object_code(test_module())))].

%%%===================================================================
%%% Internals
%%%===================================================================
test_module() -> moka_test_module.