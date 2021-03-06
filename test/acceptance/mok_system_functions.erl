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

%%% @doc Acceptance tests to verify we can mok system files
%%%
%%% This is the main reason for Moka to exists, it is something that other mocks
%%% like meck cannot do.
%%%
%%% Note that the moked code must be in a separate module, it is problematic to
%%% mok ?MODULE. Check hold_state.erl for more details.

-module(mok_system_functions).

-include_lib("eunit/include/eunit.hrl").

can_mock_read_write_test() ->
    Apps = sel_application:start_app(moka),
    Moka = moka:start(mok_system_functions_aux),
    try
        moka:replace(Moka, file, read_file, fun(_) -> test_bin() end),
        moka:replace(
          Moka, file, write_file,
          fun(_, B) ->
                  check_equal(B, test_bin()),
                  ok
          end),
        moka:load(Moka),

        mok_system_functions_aux:copy_file(
           "/this/must/not/exist/anywhere", "/this/is/also/fake")
    after
        moka:stop(Moka),
        sel_application:stop_apps(Apps)
    end.

check_equal(A, A) -> true;
check_equal(A, B) -> erlang:error({not_equal, A, B}).

test_bin() -> <<"Just something to test our fine coffee.">>.
