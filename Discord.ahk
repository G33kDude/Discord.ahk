#Persistent

#Include %A_LineFile%\..\WebSocket.ahk\WebSocket.ahk
#Include %A_LineFile%\..\AutoHotkey-JSON\Jxon.ahk

x := new Discord(FileOpen(A_Desktop "\token.txt", "r").Read())
return

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
		this.base.base.__New.Call(this, URL "?v=5&encoding=json")
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
		Print("<", Data)
		this.WebSock.Send(Jxon_Dump(Data))
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
		Print(">", Data)
		
		; Save the most recent sequence number for heartbeats
		if Data.s
			this.Seq := data.s
		
		if (Data.op == 10) ; OP 10 Hello
		{
			this.HeartbeatACK := True
			Interval := Data.d.heartbeat_interval
			SendHeartbeat := this.BoundFuncs["SendHeartbeat"]
			SetTimer, %SendHeartbeat%, %Interval%
		}
		else if (Data.op == 11) ; OP 11 Heartbeat ACK
		{
			this.HeartbeatACK := True
		}
		else if (Data.op == 0) ; OP 0 Dispatch
		{
			if (Data.t == "READY")
			{
				this.user := Data.d.user
			}
			if (Data.t == "MESSAGE_CREATE")
			{
				if (Data.d.author.id == this.user.id)
					return
				
				this.SendMessage(Data.d.channel_id, Data.d.content)
			}
		}
	}
	
	; Called by the JS on WS error
	OnError(Event)
	{
		Print("Error", Event.data)
	}
	
	; Called by the JS on WS close
	OnClose(Event)
	{
		Print("Close")
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

Print(x*){
	static c := FileOpen("CONOUT$", ("rw", DllCall("AllocConsole")))
	
	for a, b in x
	{
		if IsObject(b)
			list .= Json_FromObj(b) "`t"
		else
			list .= b "`t"
	}
	c.Write(SubStr(list, 1, -1) "`n"), c.__Handle
}