%% Event server
-module(feedserv).
-export([start/0, terminate/0, init/0, loop/0, parse_date/1]).

start() ->
    inets:start(),
    register(?MODULE, Pid1=spawn(?MODULE, init, [])),
    Pid1.

terminate() ->
    ?MODULE ! shutdown.

init() ->
    %% Loading topics from a static file could be done here.
    %% You would need to pass an argument to init (maybe change the functions
    %% start/0 and start_link/0 to start/1 and start_link/1) telling where the
    %% resource to find the topics is. Then load it from here.
    %% Another option is to just pass the topics straight to the server
    %% through this function.
    loop().

%%% The Server itself

loop() ->
    AllStories = refresh_topics(newsserv:topics_sources(), []),
    SortedStories = sort_stories(AllStories, []),
    process_insert_stories(SortedStories),
    timer:sleep(30000),
    loop().

refresh_topics([], AllStories) -> AllStories;
refresh_topics([{TopicId, Sources} | Rest], AllStories) ->
    NewAllStories = refresh_sources(TopicId, Sources, AllStories),
    refresh_topics(Rest, NewAllStories).

refresh_sources(_,[], AllStories) -> AllStories;
refresh_sources(TopicId, [{SourceName, SourceUrl} | Rest], AllStories) ->
    {feed, _Source, _Url, Stories} = feedparser:parse_url(SourceUrl),
    NewAllStories = insert_stories(TopicId, Stories, SourceName, AllStories),
    refresh_sources(TopicId, Rest, NewAllStories).

insert_stories(_,[],_, AllStories) -> AllStories;
insert_stories(TopicId, [{feedentry, HT, Date, Link, DT} | Rest], Source, AllStories) ->
    NewAllStories = [{TopicId, HT, Link, Link, DT, NewDate = parse_date(Date), Source} | AllStories],
    io:format("~W : ~p~n", [NewDate, 9, HT]),
    insert_stories(TopicId, Rest, Source, NewAllStories).
    
process_insert_stories([]) -> ok;
process_insert_stories([{TopicId, HT, Link, Link, DT, Date, Source} | Rest]) ->
    newsserv:story_add(TopicId, HT, Link, Link, DT, Date, Source),
    process_insert_stories(Rest).

sort_stories(AllStories, []) ->
    lists:keysort(6, AllStories).
    
parse_date(DateString) ->
    io:format("~s~n", [DateString]),
    {ok, [_,_,_,_,_,_,_], Left} = io_lib:fread("~3c, ~2d ~3c ~4d ~2d:~2d:~2d ", DateString),
    Date = httpd_util:convert_request_date(DateString),
    if
	Left == "GMT" ->
	    add(Date, {hours, -5});
	Left == "+0000" ->
	    add(Date, {hours, -5});
	Left == "-0800" ->
	    add(Date, {hours, 3});
	Left == "-0400" ->
	    add(Date, {hours, -1});
	Left == "-0500" ->
	    Date;
	Left == "EST" ->
	    Date;
	Left == "EDT" ->
	    add(Date, {hours, -1})
    end. 
    
	    

add(Date, {hours, N}) ->
    New = calendar:datetime_to_gregorian_seconds(Date) + (N * 60 * 60),
    calendar:gregorian_seconds_to_datetime(New).
    
    
