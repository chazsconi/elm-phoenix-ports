import {
  Socket,
  Presence
} from "phoenix"

const INTERNAL_CHANNEL_EVENTS = ["phx_close", "phx_error", "phx_join", "phx_reply", "phx_leave"]
const INTERNAL_CHANNEL_REPLY_EVENT_PREFIX = "chan_reply_"
export function init(app, opts) {
  let socket = null;
  let debug = opts && opts.debug || false
  let log = debug ? console.log : () => { }

  let pushHandlers = (push, channel, type, ref, onHandlers) => {
    if (onHandlers.onOk) {
      push.receive("ok", (msg) => {
        log("push ok", {
          topic: channel.topic,
          type: type,
          ref: ref
        })
        app.ports.pushReply.send({
          eventName: "ok",
          topic: channel.topic,
          pushType: type,
          ref: ref,
          payload: msg
        })
      })
    }
    if (onHandlers.onError) {
      push.receive("error", (reasons) => {
        log("push failed", reasons)
        app.ports.pushReply.send({
          eventName: "error",
          topic: channel.topic,
          pushType: type,
          ref: ref,
          payload: reasons
        })
      })
    }
    if (onHandlers.onTimeout) {
      push.receive("timeout", () => {
        log("push timeout")
        app.ports.pushReply.send({
          eventName: "timeout",
          topic: channel.topic,
          pushType: type,
          ref: ref,
          payload: null
        })
      })
    }
  }

  let presenceHandlers = (channel) => {
    let presence = new Presence(channel)

    let logAndSend = (eventName, presences) => {
      let payload = {
        eventName: eventName,
        topic: channel.topic,
        presences: presences
      }
      log("Presence event", payload)
      app.ports.presenceUpdated.send(payload)
    }

    // Detect user joining
    presence.onJoin((id, current, {
      metas: metas
    }) => {
      logAndSend("joined", [
        [id, metas]
      ])
    })

    // detect if user has left
    presence.onLeave((id, current, {
      metas: metas
    }) => {
      logAndSend("left", [
        [id, metas]
      ])
    })

    // receive presence data from server
    presence.onSync(() => {
      let presences = presence.list((id, {
        metas: metas
      }) => [id, metas])
      logAndSend("synced", presences)
    })
  }

  app.ports.connectSocket.subscribe(data => {
    log("connect socket: ", {
      endpoint: data.endpoint,
      params: data.params
    })

    socket = new Socket(data.endpoint, {
      params: data.params
    })
    socket.onOpen(() => {
      log("Socket opened", "")
      app.ports.socketOpened.send(null)
    })
    socket.onClose((params) => {
      log("Socket closed", params)
      app.ports.socketClosed.send({
        wasClean: params.wasClean,
        reason: params.reason,
        code: params.code
      })
    })

    socket.connect()
    log("Socket connected: ", socket)
  })

  // Join channels
  app.ports.joinChannels.subscribe(channelSpecs => {

    let channels =
      channelSpecs.map(data => {
        log("joinChannel: ", {
          topic: data.topic,
          payload: data.payload,
          onHandlers: data.onHandlers,
          presence: data.presence
        })

        let channel = socket.channel(data.topic, data.payload)

        // Listen for all message and then in Elm if there is an `on` handler execute it
        // this is simpler to implement that creating an `on` handler in JS for each one configured in Elm
        channel.onMessage = (e, payload, ref) => {
          // Filter out internal phx events so we don't pass them to elm as they will not be listened to using an `on` handler
          // and we avoid polluting the elm debugger with too many messages
          if (INTERNAL_CHANNEL_EVENTS.includes(e) || e.startsWith(INTERNAL_CHANNEL_REPLY_EVENT_PREFIX)) {
            return payload
          }

          app.ports.channelMessage.send([channel.topic, e, payload])
          return payload
        }

        channel.onError(() => {
          log("Error on channel", channel.topic)
          app.ports.channelError.send(channel.topic)
        })

        if (data.presence) {
          presenceHandlers(channel)
        }

        let push = channel.join()
        pushHandlers(push, channel, "join", null, data.onHandlers)

        return channel
      })
    app.ports.channelsCreated.send(channels.map(channel => [channel.topic, channel]));

  });


  // Leave channel
  app.ports.leaveChannel.subscribe(channel => {
    log("leaveChannel: ", {
      channel: channel
    })

    let push = channel.leave()
    pushHandlers(push, channel, "leave", null, {
      onOk: true,
      onError: true,
      onTimeout: false
    })
  })

  // Push
  app.ports.pushChannel.subscribe(data => {
    log("Push", {
      topic: data.channel.topic,
      event: data.event,
      payload: data.payload,
      ref: data.ref,
      onHandlers: data.onHandlers
    })

    let channel = data.channel
    let push = channel.push(data.event, data.payload, 10000)
    pushHandlers(push, channel, "msg", data.ref, data.onHandlers)
  })
}
