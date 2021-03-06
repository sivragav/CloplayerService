%% Copyright (c) 2007, Kevin A. Smith<kevin@hypotheticalabs.com>
%% 
%% All rights reserved.
%% 
%% Redistribution and use in source and binary forms, with or without 
%% modification, are permitted provided that the following 
%% conditions are met:
%% 
%% * Redistributions of source code must retain the above copyright notice, 
%% this list of conditions and the following disclaimer.
%% 
%% * Redistributions in binary form must reproduce the above copyright 
%% notice, this list of conditions and the following disclaimer in the 
%% documentation and/or other materials provided with the distribution.
%% 
%% * Neither the name of the hypotheticalabs.com nor the names of its 
%% contributors may be used to endorse or promote products derived from 
%% this software without specific prior written permission.
%% 
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
%% A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
%% OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
%% SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
%% LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
%% DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
%% THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR 
%% TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
%% THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
%% DAMAGE.

-module(rss_parser).

-export([parse_feed/1]).

-include("feedparser.hrl").

parse_feed(RawFeed) ->
    CB = fun(Event, State) ->
		 handle_event(Event, State)
	 end,
    erlsom:sax(RawFeed, [], CB).

handle_event(startDocument, _State) ->
	[{cmd, start}, {md, #feed{}}, {entries, []}];

handle_event({startElement, _NS, "title", _, _Attrs}, [{cmd, start}, {md, Feed}, {entries, Entries}]) ->
	build_state(titletext, Feed, Entries);

handle_event({characters, Text}, [{cmd, titletext}, {md, Feed}, {entries, Entries}]) ->
	build_state(start, Feed#feed{title=Text}, Entries);

handle_event({startElement, _NS, "link", _, _Attrs}, [{cmd, start}, {md, Feed}, {entries, Entries}]) ->
	build_state(permalinktext, Feed, Entries);

handle_event({characters, Text}, [{cmd, permalinktext}, {md, Feed}, {entries, Entries}]) ->
	build_state(start, Feed#feed{url=Text}, Entries);

handle_event({startElement, _NS, "item", _, _Attrs}, [{cmd, _}, {md, Feed}, {entries, Entries}]) ->
	build_state(entry, Feed, [#feedentry{content=""}|Entries]);

handle_event({startElement, _NS, "title", _, _Attrs}, [{cmd, entry}, {md, Feed}, {entries, Entries}]) ->
	build_state(entrytitletext, Feed, Entries);

handle_event({characters, Text}, [{cmd, entrytitletext}, {md, Feed}, {entries, Entries}]) ->
	[Entry|T] = Entries,
	UpdatedEntry = Entry#feedentry{title=Text},
	build_state(entry, Feed, [UpdatedEntry|T]);

handle_event({startElement, _NS, "link", _, _Attrs}, [{cmd, entry}, {md, Feed}, {entries, Entries}]) ->
	build_state(entrylinktext, Feed, Entries);

handle_event({characters, Text}, [{cmd, entrylinktext}, {md, Feed}, {entries, Entries}]) ->
 	[Entry|T] = Entries,
 	UpdatedEntry = Entry#feedentry{permalink=Text},
	build_state(entry, Feed, [UpdatedEntry|T]);

handle_event({startElement, _NS, "description", _, _Attrs}, [{cmd, entry}, {md, Feed}, {entries, Entries}]) ->
	build_state(entrycontenttext, Feed, Entries);

handle_event({characters, Text}, [{cmd, entrycontenttext}, {md, Feed}, {entries, Entries}]) ->
 	[Entry|T] = Entries,
	UpdatedEntry = Entry#feedentry{content=lists:append(Entry#feedentry.content, Text)},
	UpdatedEntries = [UpdatedEntry|T],
	build_state(entry, Feed, UpdatedEntries);

handle_event({startElement, _NS, "pubDate", _, _Attrs}, [{cmd, entry}, {md, Feed}, {entries, Entries}]) ->
	build_state(entrydatetext, Feed, Entries);

handle_event({characters, Text}, [{cmd, entrydatetext}, {md, Feed}, {entries, Entries}]) ->
 	[Entry|T] = Entries,
	UpdatedEntry = Entry#feedentry{date=Text},
	UpdatedEntries = [UpdatedEntry|T],
	build_state(entry, Feed, UpdatedEntries);

handle_event({startElement, _NS, "content", _, _Attrs}, [{cmd, entry}, {md, Feed}, {entries, Entries}]) ->
	build_state(content, Feed, Entries);

handle_event({endElement, _NS, "content", _}, [{cmd, _Command}, {md, Feed}, {entries, Entries}]) ->
	build_state(entry, Feed, Entries);

handle_event({endElement, _NS, "rss", _}, [{cmd, _Command}, {md, Feed}, {entries, Entries}]) ->
	Feed#feed{entries=Entries};

handle_event(_Event, State) ->
	State.

build_state(Command, Feed, Entries) ->
	lists:flatten([build_cmd(Command), build_state(Feed, Entries)]).

build_state(Feed, Entries) ->
   [{md, Feed}, {entries, Entries}].

build_cmd(Command) ->
	{cmd, Command}.

