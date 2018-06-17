#Include %A_LineFile%\..\Lib\WebSocket.ahk\WebSocket.ahk
#Include %A_LineFile%\..\Lib\AutoHotkey-JSON\Jxon.ahk

class Discord extends WebSocket
{
	static BaseURL := "https://discordapp.com/api"
	
	__New(Token)
	{
		; Bind some functions for later use
		this.BoundFuncs := {}
		for each, name in ["SaveWS", "OnOpen", "OnClose", "OnError", "OnMessage", "SendHeartbeat"]
			this.BoundFuncs[name] := this[name].Bind(this)
		
		; Save the token
		this.Token := Token
		
		; Get the gateway websocket URL
		URL := this.CallAPI("GET", "/gateway/bot").url
		
		; Connect to the server
		WebSocket.__New.Call(this, URL "?v=6&encoding=json")
	}
	
	; Calls the REST API
	CallAPI(Method, Endpoint, Data="")
	{
		Http := ComObjCreate("WinHTTP.WinHTTPRequest.5.1")
		Http.Open(Method, this.BaseURL . Endpoint)
		Http.SetRequestHeader("Authorization", "Bot " this.Token)
		Http.SetRequestHeader("Content-Type", "application/json")
		if Data
			Http.Send(Jxon_Dump(Data))
		else
			Http.Send()
		return Jxon_Load(Http.ResponseText())
	}
	
	; Sends data through the websocket
	Send(Data)
	{
		WebSocket.Send.Call(this, Jxon_Dump(Data))
	}
	
	; Sends the Identify operation
	SendIdentify()
	{
		this.Send(
		( LTrim Join
		{
			"op": 2,
			"d": {
				"token": this.Token,
				"properties": {
					"$os": "windows",
					"$browser": "Discord.ahk",
					"$device": "Discord.ahk",
					"$referrer": "",
					"$referring_domain": ""
				},
				"compress": true,
				"large_threshold": 250
			}
		}
		))
	}
	
	; Sends a message to a channel
	SendMessage(channel_id, content)
	{
		return this.CallAPI("POST", "/channels/" channel_id "/messages", {"content": content})
	}
	
	; Called by the JS on WS open
	OnOpen(Event)
	{
		this.SendIdentify()
	}
	
	; Called by the JS on WS message
	OnMessage(Event)
	{
		Data := Jxon_Load(Event.data)
		
		; Save the most recent sequence number for heartbeats
		if Data.s
			this.Seq := data.s
		
		; Call the defined handler, if any
		fn := this["OP" Data.op]
		%fn%(this, Data)
	}
	
	; OP 10 Hello
	OP10(Data)
	{
		this.HeartbeatACK := True
		Interval := Data.d.heartbeat_interval
		SendHeartbeat := this.BoundFuncs["SendHeartbeat"]
		SetTimer, %SendHeartbeat%, %Interval%
	}
	
	; OP 11 Heartbeat ACK
	OP11(Data)
	{
		this.HeartbeatACK := True
	}
	
	; OP 0 Dispatch
	OP0(Data)
	{
		; Call the defined handler, if any
		fn := this["OP0_" Data.t]
		%fn%(this, Data.d)
	}
	
	; Called by the JS on WS error
	OnError(Event)
	{
		throw Exception("Unhandled Discord.ahk WebSocket Error")
	}
	
	; Called by the JS on WS close
	OnClose(Event)
	{
		throw Exception("Unhandled Discord.ahk WebSocket Close")
	}
	
	; Gets called periodically by a timer to send a heartbeat operation
	SendHeartbeat()
	{
		if !this.HeartbeatACK
		{
			throw Exception("Heartbeat did not respond")
			/*
				If a client does not receive a heartbeat ack between its
				attempts at sending heartbeats, it should immediately terminate
				the connection with a non 1000 close code, reconnect, and
				attempt to resume.
			*/
		}
		
		this.HeartbeatACK := False
		this.Send({"op": 1, "d": this.Seq})
	}
}