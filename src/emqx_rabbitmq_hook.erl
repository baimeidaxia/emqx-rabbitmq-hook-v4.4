%%--------------------------------------------------------------------
%% Copyright (c) 2020 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_rabbitmq_hook).

-include("emqx.hrl").

-include("emqx_rabbitmq_hook.hrl").

-behaviour(ecpool_worker).

-export([ connect/1
        , load/1
        , unload/0
        ]).

%% Client Lifecircle Hooks
-export([ on_client_connect/3
        , on_client_connack/4
        , on_client_connected/3
        , on_client_disconnected/4
        , on_client_authenticate/3
        , on_client_check_acl/5
        , on_client_subscribe/4
        , on_client_unsubscribe/4
        ]).

%% Session Lifecircle Hooks
-export([ on_session_created/3
        , on_session_subscribed/4
        , on_session_unsubscribed/4
        , on_session_resumed/3
        , on_session_discarded/3
        , on_session_takeovered/3
        , on_session_terminated/4
        ]).

%% Message Pubsub Hooks
-export([ on_message_publish/2
        , on_message_delivered/3
        , on_message_acked/3
        , on_message_dropped/4
        ]).

%% Called when the plugin application start
load(Env) ->
    emqx:hook('client.connect',      {?MODULE, on_client_connect, [Env]}),
    emqx:hook('client.connack',      {?MODULE, on_client_connack, [Env]}),
    emqx:hook('client.connected',    {?MODULE, on_client_connected, [Env]}),
    emqx:hook('client.disconnected', {?MODULE, on_client_disconnected, [Env]}),
    emqx:hook('client.authenticate', {?MODULE, on_client_authenticate, [Env]}),
    emqx:hook('client.check_acl',    {?MODULE, on_client_check_acl, [Env]}),
    emqx:hook('client.subscribe',    {?MODULE, on_client_subscribe, [Env]}),
    emqx:hook('client.unsubscribe',  {?MODULE, on_client_unsubscribe, [Env]}),
    emqx:hook('session.created',     {?MODULE, on_session_created, [Env]}),
    emqx:hook('session.subscribed',  {?MODULE, on_session_subscribed, [Env]}),
    emqx:hook('session.unsubscribed',{?MODULE, on_session_unsubscribed, [Env]}),
    emqx:hook('session.resumed',     {?MODULE, on_session_resumed, [Env]}),
    emqx:hook('session.discarded',   {?MODULE, on_session_discarded, [Env]}),
    emqx:hook('session.takeovered',  {?MODULE, on_session_takeovered, [Env]}),
    emqx:hook('session.terminated',  {?MODULE, on_session_terminated, [Env]}),
    emqx:hook('message.publish',     {?MODULE, on_message_publish, [Env]}),
    emqx:hook('message.delivered',   {?MODULE, on_message_delivered, [Env]}),
    emqx:hook('message.acked',       {?MODULE, on_message_acked, [Env]}),
    emqx:hook('message.dropped',     {?MODULE, on_message_dropped, [Env]}).

%%--------------------------------------------------------------------
%% Client Lifecircle Hooks
%%--------------------------------------------------------------------

on_client_connect(ConnInfo = #{clientid := ClientId}, Props, _Env) ->
    io:format("Client(~s) connect, ConnInfo: ~p, Props: ~p~n",
              [ClientId, ConnInfo, Props]),
    {ok, Props}.

on_client_connack(ConnInfo = #{clientid := ClientId}, Rc, Props, _Env) ->
    io:format("Client(~s) connack, ConnInfo: ~p, Rc: ~p, Props: ~p~n",
              [ClientId, ConnInfo, Rc, Props]),
    {ok, Props}.

on_client_connected(ClientInfo = #{clientid := ClientId}, ConnInfo, _Env) ->
    io:format("Client(~s) connected, ClientInfo:~n~p~n, ConnInfo:~n~p~n", [ClientId, ClientInfo, ConnInfo]),
    publish_message("client.connected", "client.connected", #{
			clientInfo => ClientInfo#{peerhost := ip_to_binary(maps:get(peerhost, ClientInfo))},
			connInfo => ConnInfo#{peername := ip_port_to_binary(maps:get(peername, ConnInfo)), 
			sockname := ip_port_to_binary(maps:get(sockname, ConnInfo))}
		}
	).

on_client_disconnected(ClientInfo = #{clientid := ClientId}, ReasonCode, ConnInfo, _Env) ->
    io:format("Client(~s) disconnected due to ~p, ClientInfo:~n~p~n, ConnInfo:~n~p~n", [ClientId, ReasonCode, ClientInfo, ConnInfo]),
    publish_message("client.disconnected", "client.disconnected", #{
			clientInfo => ClientInfo#{peerhost := ip_to_binary(maps:get(peerhost, ClientInfo))},
		    connInfo => ConnInfo#{peername := ip_port_to_binary(maps:get(peername, ConnInfo)),
			sockname := ip_port_to_binary(maps:get(sockname, ConnInfo))},
			reasonCode => ReasonCode
		}
	).

on_client_authenticate(_ClientInfo = #{clientid := ClientId}, Result, _Env) ->
    io:format("Client(~s) authenticate, Result:~n~p~n", [ClientId, Result]),
    {ok, Result}.

on_client_check_acl(_ClientInfo = #{clientid := ClientId}, Topic, PubSub, Result, _Env) ->
    io:format("Client(~s) check_acl, PubSub:~p, Topic:~p, Result:~p~n",
              [ClientId, PubSub, Topic, Result]),
    {ok, Result}.

on_client_subscribe(#{clientid := ClientId}, _Properties, TopicFilters, _Env) ->
    io:format("Client(~s) will subscribe: ~p~n", [ClientId, TopicFilters]),
    {ok, TopicFilters}.

on_client_unsubscribe(#{clientid := ClientId}, _Properties, TopicFilters, _Env) ->
    io:format("Client(~s) will unsubscribe ~p~n", [ClientId, TopicFilters]),
    {ok, TopicFilters}.

%%--------------------------------------------------------------------
%% Session Lifecircle Hooks
%%--------------------------------------------------------------------

on_session_created(#{clientid := ClientId}, SessInfo, _Env) ->
    io:format("Session(~s) created, Session Info:~n~p~n", [ClientId, SessInfo]).

on_session_subscribed(#{clientid := ClientId}, Topic, SubOpts, _Env) ->
    io:format("Session(~s) subscribed ~s with subopts: ~p~n", [ClientId, Topic, SubOpts]),
    publish_message(Topic, "session.subscribed", #{
			clientInfo => ClientInfo#{peerhost := ip_to_binary(maps:get(peerhost, ClientInfo))},
		    topic => Topic, opts => SubOpts
		}
	).

on_session_unsubscribed(#{clientid := ClientId}, Topic, Opts, _Env) ->
    io:format("Session(~s) unsubscribed ~s with opts: ~p~n", [ClientId, Topic, Opts]).

on_session_resumed(#{clientid := ClientId}, SessInfo, _Env) ->
    io:format("Session(~s) resumed, Session Info:~n~p~n", [ClientId, SessInfo]).

on_session_discarded(_ClientInfo = #{clientid := ClientId}, SessInfo, _Env) ->
    io:format("Session(~s) is discarded. Session Info: ~p~n", [ClientId, SessInfo]).

on_session_takeovered(_ClientInfo = #{clientid := ClientId}, SessInfo, _Env) ->
    io:format("Session(~s) is takeovered. Session Info: ~p~n", [ClientId, SessInfo]).

on_session_terminated(_ClientInfo = #{clientid := ClientId}, Reason, SessInfo, _Env) ->
    io:format("Session(~s) is terminated due to ~p~nSession Info: ~p~n",
              [ClientId, Reason, SessInfo]).

%%--------------------------------------------------------------------
%% Message PubSub Hooks
%%--------------------------------------------------------------------

%% Transform message and return
on_message_publish(Message = #message{topic = <<"$SYS/", _/binary>>}, _Env) ->
    {ok, Message};

on_message_publish(Message, _Env) ->
    io:format("Publish ~s~n", [emqx_message:format(Message)]),
    #message{qos = QoS, topic = Topic, from = From, flags = Flags, headers = Headers, payload = Payload, timestamp = Timestamp} = Message,
    publish_message(Topic, "message.publish", #{
			id => emqx_guid:to_hexstr(emqx_guid:gen()),
		    qos => QoS, topic => Topic, from => From,
		    flags => Flags,
		    headers => Headers#{peerhost => ip_to_binary(maps:get(peerhost, Headers, {}))},
		    payload => Payload, timestamp => Timestamp
		}
	).

on_message_dropped(#message{topic = <<"$SYS/", _/binary>>}, _By, _Reason, _Env) ->
    ok;
on_message_dropped(Message, _By = #{node := Node}, Reason, _Env) ->
    io:format("Message dropped by node ~s due to ~s: ~s~n", [Node, Reason, emqx_message:format(Message)]),
	#message{qos = QoS, topic = Topic, from = From, flags = Flags, headers = Headers, payload = Payload, timestamp = Timestamp} = Message,
    publish_message(Topic, "message.dropped", #{
			id => emqx_guid:to_hexstr(emqx_guid:gen()),
		    qos => QoS, topic => Topic, from => From,
		    flags => Flags,
		    headers => Headers#{peerhost => ip_to_binary(maps:get(peerhost, Headers, {}))},
		    payload => Payload, timestamp => Timestamp,
			reason => Reason
		}
	).

on_message_delivered(_ClientInfo = #{clientid := ClientId}, Message, _Env) ->
    io:format("Message delivered to client(~s): ~s~n",
              [ClientId, emqx_message:format(Message)]),
    {ok, Message}.

on_message_acked(_ClientInfo = #{clientid := ClientId}, Message, _Env) ->
    io:format("Message acked by client(~s): ~s~n", [ClientId, emqx_message:format(Message)]),
	#message{qos = QoS, topic = Topic, from = From, flags = Flags, headers = Headers, payload = Payload, timestamp = Timestamp} = Message,
    publish_message(Topic, "message.acked", #{
			id => emqx_guid:to_hexstr(emqx_guid:gen()),
		    qos => QoS, topic => Topic, from => From,
		    flags => Flags,
		    headers => Headers#{peerhost => ip_to_binary(maps:get(peerhost, Headers, {}))},
		    payload => Payload, timestamp => Timestamp
		}
	).

connect(Opts) ->
    io:format("connent opts ~p~n", [Opts]),
    {ok, Host} = application:get_env(?APP, host),
    {ok, Port} = application:get_env(?APP, port),
    {ok, Username} = application:get_env(?APP, username),
    {ok, Password} = application:get_env(?APP, password),
    ConnOpts = #amqp_params_network{
					host = Host,
				    port = Port,
				    username = list_to_binary(Username),
				    password = list_to_binary(Password)
				},
    {ok, C} = amqp_connection:start(ConnOpts),
    io:format("amqp connection started~n"),
    {ok, C}.


publish_message(Topic, Event, Payload) ->
    ecpool:with_client(?APP, fun (C) -> publish_message(Topic, Event, Payload, C) end).

publish_message(Topic, Event, Payload, Connection) ->
	RoutingKey = list_to_binary(string:replace(Topic, "/", ".", all)),
	io:format("convert topic/~s to routingKey/~s with event/~s ~n", [Topic, RoutingKey, Event]),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    {ok, Exchange} = application:get_env(?APP, exchange),
    Publish = #'basic.publish'{exchange = list_to_binary(Exchange), routing_key = RoutingKey},
    amqp_channel:cast(Channel, Publish, #amqp_msg{
			payload = jsx:encode(Payload), 
			props = #'P_basic'{
						content_type = <<"application/json">>,
						content_encoding = <<"UTF-8">>,
						headers = [{"type", longstr, Event}]
					}
		}
	),
    amqp_channel:close(Channel).

ip_to_binary(IpTuple) -> list_to_binary(ip_to_string(IpTuple)).

ip_to_string(IpTuple) -> string:join(lists:map(fun (X) -> integer_to_list(X) end, tuple_to_list(IpTuple)), ".").

ip_port_to_binary(IpPortTuple) -> 
	{IP_Tuple, Port} = IpPortTuple,
    IpStr = ip_to_string(IP_Tuple),
    PortStr = integer_to_list(Port),
    list_to_binary(string:join([IpStr, PortStr], ":")).

%% Called when the plugin application stop
unload() ->
    emqx:unhook('client.connect',      {?MODULE, on_client_connect}),
    emqx:unhook('client.connack',      {?MODULE, on_client_connack}),
    emqx:unhook('client.connected',    {?MODULE, on_client_connected}),
    emqx:unhook('client.disconnected', {?MODULE, on_client_disconnected}),
    emqx:unhook('client.authenticate', {?MODULE, on_client_authenticate}),
    emqx:unhook('client.check_acl',    {?MODULE, on_client_check_acl}),
    emqx:unhook('client.subscribe',    {?MODULE, on_client_subscribe}),
    emqx:unhook('client.unsubscribe',  {?MODULE, on_client_unsubscribe}),
    emqx:unhook('session.created',     {?MODULE, on_session_created}),
    emqx:unhook('session.subscribed',  {?MODULE, on_session_subscribed}),
    emqx:unhook('session.unsubscribed',{?MODULE, on_session_unsubscribed}),
    emqx:unhook('session.resumed',     {?MODULE, on_session_resumed}),
    emqx:unhook('session.discarded',   {?MODULE, on_session_discarded}),
    emqx:unhook('session.takeovered',  {?MODULE, on_session_takeovered}),
    emqx:unhook('session.terminated',  {?MODULE, on_session_terminated}),
    emqx:unhook('message.publish',     {?MODULE, on_message_publish}),
    emqx:unhook('message.delivered',   {?MODULE, on_message_delivered}),
    emqx:unhook('message.acked',       {?MODULE, on_message_acked}),
    emqx:unhook('message.dropped',     {?MODULE, on_message_dropped}).

