// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/bumblebee_lns"
import {Hooks as BackpexHooks} from "backpex"
import L from "leaflet"
import topbar from "../vendor/topbar"

BackpexHooks.BackpexThemeSelector.setStoredTheme()

const BackpexThemeSelector = {
  ...BackpexHooks.BackpexThemeSelector,
  mounted() {
    BackpexHooks.BackpexThemeSelector.mounted.call(this)
  },
}

const GatewayLocationMap = {
  mounted() {
    this.latitudeInput = document.getElementById(this.el.dataset.latitudeInput)
    this.longitudeInput = document.getElementById(this.el.dataset.longitudeInput)

    if (!this.latitudeInput || !this.longitudeInput) {
      return
    }

    const position = this.currentPosition()
    const hasPosition = position !== null
    const center = position || [20, 0]

    this.map = L.map(this.el, {scrollWheelZoom: false}).setView(center, hasPosition ? 13 : 2)

    L.tileLayer(this.el.dataset.tileUrl, {
      attribution: "&copy; OpenStreetMap contributors",
      maxZoom: 19,
    }).addTo(this.map)

    this.marker = L.marker(center, {
      draggable: true,
      icon: L.divIcon({
        className: "gateway-location-marker",
        html: "<span></span>",
        iconSize: [24, 24],
        iconAnchor: [12, 12],
      }),
    }).addTo(this.map)

    this.marker.on("dragend", () => this.setPosition(this.marker.getLatLng()))
    this.map.on("click", event => this.setPosition(event.latlng))

    this.onInputChanged = () => this.syncMarkerFromInputs()
    this.latitudeInput.addEventListener("input", this.onInputChanged)
    this.longitudeInput.addEventListener("input", this.onInputChanged)

    requestAnimationFrame(() => this.map.invalidateSize())
  },

  updated() {
    if (this.map) {
      requestAnimationFrame(() => {
        this.map.invalidateSize()
        this.syncMarkerFromInputs()
      })
    }
  },

  destroyed() {
    if (this.latitudeInput && this.onInputChanged) {
      this.latitudeInput.removeEventListener("input", this.onInputChanged)
    }

    if (this.longitudeInput && this.onInputChanged) {
      this.longitudeInput.removeEventListener("input", this.onInputChanged)
    }

    if (this.map) {
      this.map.remove()
    }
  },

  currentPosition() {
    const latitude = Number.parseFloat(this.latitudeInput.value)
    const longitude = Number.parseFloat(this.longitudeInput.value)

    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return null
    }

    return [latitude, longitude]
  },

  setPosition(latlng) {
    const latitude = roundCoordinate(latlng.lat)
    const longitude = roundCoordinate(latlng.lng)

    this.latitudeInput.value = latitude
    this.longitudeInput.value = longitude
    this.marker.setLatLng([latitude, longitude])

    dispatchInput(this.latitudeInput)
    dispatchInput(this.longitudeInput)
  },

  syncMarkerFromInputs() {
    const position = this.currentPosition()

    if (position) {
      this.marker.setLatLng(position)
    }
  },
}

function roundCoordinate(value) {
  return Number.parseFloat(value).toFixed(6)
}

function dispatchInput(input) {
  input.dispatchEvent(new Event("input", {bubbles: true}))
  input.dispatchEvent(new Event("change", {bubbles: true}))
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...BackpexHooks, ...BackpexThemeSelector, GatewayLocationMap},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => {
  topbar.hide()
  applyStoredBackpexTheme()
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
