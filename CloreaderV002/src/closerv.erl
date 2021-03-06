-module(closerv).
-export([start/1, stop/0]).

% start misultin http server
start(Port) ->
    newsserv:start(),
    feedserv:start(),
    misultin:start_link([{port, Port}, {loop, fun(Req) -> handle_http(Req) end}]).

% stop misultin
stop() ->
    misultin:stop(),
    feedserv:terminate(),
    newsserv:terminate().

% callback function called on incoming http request
handle_http(Req) ->
	% dispatch to rest
	Args = Req:parse_qs(),
	Result = newsserv:execute_api(Req:get(method), Req:resource([lowercase, urldecode]), Req, Args),
	Req:ok([{"Content-Type", "text/plain"}], binary_to_list(jsx:term_to_json(Result))).


