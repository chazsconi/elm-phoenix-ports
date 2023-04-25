import '../css/app.css'
import * as elmChat from '../elm_build/elm.js'
import * as elmPhoenix from "elm-phoenix-ports"


const elmDiv = document.querySelector("#elm-container");
const elmApp = elmChat.Elm.Chat.init({ node: elmDiv });
elmPhoenix.init(elmApp, { debug: true });
