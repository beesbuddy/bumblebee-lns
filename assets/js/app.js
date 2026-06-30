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
import {
  Chart,
  Filler,
  Legend,
  LinearScale,
  LineController,
  LineElement,
  PointElement,
  ScatterController,
  Tooltip,
} from "chart.js"

Chart.register(
  Filler,
  Legend,
  LinearScale,
  LineController,
  LineElement,
  PointElement,
  ScatterController,
  Tooltip
)

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

const TrafficGraphNavigator = {
  mounted() {
    this.drag = null
    this.selection = null
    this.selectionEl = null
    this.wheelTimer = null
    this.chart = null
    this.renderChart()

    this.onPointerDown = event => {
      if (event.button !== 0 || !this.canNavigate()) {
        return
      }

      const ratio = this.pointerRatio(event)
      if (ratio === null) {
        return
      }

      if (event.shiftKey) {
        event.preventDefault()
        this.selection = {
          pointerId: event.pointerId,
          startRatio: ratio,
          endRatio: ratio,
          mode: event.altKey ? "out" : "in",
        }
        this.showSelection()
        this.updateSelection(ratio)
        this.el.setPointerCapture(event.pointerId)
        return
      }

      this.drag = {
        pointerId: event.pointerId,
        startX: event.clientX,
        lastX: event.clientX,
        moved: false,
      }

      this.el.setPointerCapture(event.pointerId)
      this.el.classList.add("cursor-grabbing")
    }

    this.onPointerMove = event => {
      if (!this.drag || event.pointerId !== this.drag.pointerId) {
        if (this.selection && event.pointerId === this.selection.pointerId) {
          event.preventDefault()
          const ratio = this.pointerRatio(event)
          if (ratio !== null) {
            this.selection.endRatio = ratio
            this.updateSelection(ratio)
          }
        }
        return
      }

      this.drag.lastX = event.clientX
      this.drag.moved = this.drag.moved || Math.abs(this.drag.lastX - this.drag.startX) > 4
    }

    this.onPointerUp = event => {
      if (!this.drag || event.pointerId !== this.drag.pointerId) {
        if (this.selection && event.pointerId === this.selection.pointerId) {
          this.finishSelection(event)
        }
        return
      }

      const drag = this.drag
      this.drag = null
      this.el.classList.remove("cursor-grabbing")

      if (this.el.hasPointerCapture(event.pointerId)) {
        this.el.releasePointerCapture(event.pointerId)
      }

      const deltaX = event.clientX - drag.startX
      if (!drag.moved || Math.abs(deltaX) < 12) {
        return
      }

      const duration = this.windowDuration()
      const width = this.chartWidth()
      if (!duration || !width) {
        return
      }

      const seconds = Math.round((-deltaX / width) * duration)
      if (seconds !== 0) {
        this.pushEvent("pan_traffic_window", {seconds})
      }
    }

    this.onPointerCancel = event => {
      if (this.drag && event.pointerId === this.drag.pointerId) {
        this.drag = null
        this.el.classList.remove("cursor-grabbing")
      }

      if (this.selection && event.pointerId === this.selection.pointerId) {
        this.clearSelection()
      }
    }

    this.onWheel = event => {
      if (!this.canNavigate()) {
        return
      }

      if (Math.abs(event.deltaY) < Math.abs(event.deltaX)) {
        return
      }

      event.preventDefault()

      window.clearTimeout(this.wheelTimer)
      this.wheelTimer = window.setTimeout(() => {
        const direction = event.deltaY < 0 ? "in" : "out"
        const anchor = this.pointerRatio(event)
        this.pushEvent("zoom_traffic_window", {direction, anchor: anchor ?? 0.5})
      }, 80)
    }

    this.onDoubleClick = event => {
      if (!this.canNavigate()) {
        return
      }

      const anchor = this.pointerRatio(event)
      if (anchor === null) {
        return
      }

      event.preventDefault()
      this.pushEvent("zoom_traffic_window", {
        direction: event.shiftKey || event.altKey ? "out" : "in",
        anchor,
      })
    }

    this.el.addEventListener("pointerdown", this.onPointerDown)
    this.el.addEventListener("pointermove", this.onPointerMove)
    this.el.addEventListener("pointerup", this.onPointerUp)
    this.el.addEventListener("pointercancel", this.onPointerCancel)
    this.el.addEventListener("wheel", this.onWheel, {passive: false})
    this.el.addEventListener("dblclick", this.onDoubleClick)
  },

  destroyed() {
    window.clearTimeout(this.wheelTimer)
    this.clearSelection()
    this.destroyChart()
    this.el.removeEventListener("pointerdown", this.onPointerDown)
    this.el.removeEventListener("pointermove", this.onPointerMove)
    this.el.removeEventListener("pointerup", this.onPointerUp)
    this.el.removeEventListener("pointercancel", this.onPointerCancel)
    this.el.removeEventListener("wheel", this.onWheel)
    this.el.removeEventListener("dblclick", this.onDoubleClick)
  },

  updated() {
    this.renderChart()
  },

  canNavigate() {
    return this.el.dataset.windowKey !== "all" && Number.isFinite(this.windowDuration())
  },

  windowDuration() {
    const duration = Number.parseFloat(this.el.dataset.windowDuration)
    return Number.isFinite(duration) && duration > 0 ? duration : null
  },

  chartWidth() {
    const canvas = this.el.querySelector("canvas")
    const width = canvas?.getBoundingClientRect().width || this.el.getBoundingClientRect().width
    return width > 0 ? width : null
  },

  chartRect() {
    return this.el.querySelector("canvas")?.getBoundingClientRect() || this.el.getBoundingClientRect()
  },

  pointerRatio(event) {
    const rect = this.chartRect()
    if (!rect || rect.width <= 0) {
      return null
    }

    return Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width))
  },

  showSelection() {
    if (this.selectionEl) {
      return
    }

    const element = document.createElement("div")
    element.style.position = "absolute"
    element.style.top = "0"
    element.style.bottom = "0"
    element.style.border = "1px solid color-mix(in oklab, var(--color-primary) 70%, transparent)"
    element.style.background = "color-mix(in oklab, var(--color-primary) 16%, transparent)"
    element.style.pointerEvents = "none"
    element.style.zIndex = "2"
    this.selectionEl = element
    this.el.appendChild(element)
  },

  updateSelection(ratio) {
    if (!this.selection || !this.selectionEl) {
      return
    }

    const start = Math.min(this.selection.startRatio, ratio) * 100
    const end = Math.max(this.selection.startRatio, ratio) * 100
    this.selectionEl.style.left = `${start}%`
    this.selectionEl.style.width = `${Math.max(0.4, end - start)}%`
    this.selectionEl.style.background =
      this.selection.mode === "out"
        ? "color-mix(in oklab, var(--color-warning) 18%, transparent)"
        : "color-mix(in oklab, var(--color-primary) 16%, transparent)"
  },

  finishSelection(event) {
    const selection = this.selection
    const ratio = this.pointerRatio(event)
    this.clearSelection()

    if (!selection || ratio === null || Math.abs(ratio - selection.startRatio) < 0.02) {
      return
    }

    this.pushEvent("zoom_traffic_interval", {
      start: selection.startRatio,
      end: ratio,
      mode: selection.mode,
    })
  },

  clearSelection() {
    this.selection = null
    if (this.selectionEl) {
      this.selectionEl.remove()
      this.selectionEl = null
    }
  },

  renderChart() {
    const canvas = this.el.querySelector("canvas")
    const spec = parseChartSpec(this.el.dataset.chartSpec)

    if (!canvas || !spec) {
      this.destroyChart()
      return
    }

    this.destroyChart()
    this.chart = new Chart(canvas, trafficChartConfig(spec, this.el))
  },

  destroyChart() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  },
}

const trafficLanePlugin = {
  id: "trafficLanePlugin",
  afterDatasetsDraw(chart) {
    const {ctx, chartArea} = chart
    const laneColor = chart.options.plugins.trafficLanes?.laneColor || "#d1d5db"
    const labelColor = chart.options.plugins.trafficLanes?.labelColor || "#6b7280"
    const lanes = [
      {label: "Events", ratio: 0.16},
      {label: "Frames", ratio: 0.06},
    ]

    ctx.save()
    ctx.lineWidth = 1
    ctx.strokeStyle = laneColor
    ctx.fillStyle = labelColor
    ctx.font = "11px sans-serif"
    ctx.textAlign = "left"
    ctx.textBaseline = "middle"

    for (const lane of lanes) {
      const y = chart.scales.y.getPixelForValue(chart.scales.y.max * lane.ratio)
      if (y < chartArea.top || y > chartArea.bottom) {
        continue
      }

      ctx.beginPath()
      ctx.moveTo(chartArea.left, y)
      ctx.lineTo(chartArea.right, y)
      ctx.stroke()
      ctx.fillText(lane.label, chartArea.left + 8, y - 10)
    }

    ctx.restore()
  },
}

Chart.register(trafficLanePlugin)

function parseChartSpec(value) {
  if (!value) {
    return null
  }

  try {
    return JSON.parse(value)
  } catch (_error) {
    return null
  }
}

function trafficChartConfig(spec, element) {
  const style = getComputedStyle(document.documentElement)
  const colors = {
    primary: cssColor(style, "--color-primary", "#2563eb"),
    error: cssColor(style, "--color-error", "#dc2626"),
    warning: cssColor(style, "--color-warning", "#d97706"),
    info: cssColor(style, "--color-info", "#0891b2"),
    baseContent: cssColor(style, "--color-base-content", "#111827"),
    base300: cssColor(style, "--color-base-300", "#d1d5db"),
  }
  const values = spec.data?.values || []
  const observability = spec.observability?.values || []
  const yMax = Math.max(4, Number(spec.bounds?.y_max) || 4)

  return {
    type: "line",
    data: {
      datasets: [
        lineDataset(values, "Requests per min", "Requests", colors.primary),
        lineDataset(values, "Errors per min", "Errors", colors.error),
        markerDataset(observability, "event", "Events", yMax * 0.16, colors),
        markerDataset(observability, "frame", "Frames", yMax * 0.06, colors),
      ].filter(dataset => dataset.data.length > 0),
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: false,
      normalized: true,
      parsing: false,
      interaction: {
        intersect: false,
        mode: "nearest",
      },
      layout: {
        padding: {
          top: 10,
          right: 14,
          bottom: 4,
          left: 4,
        },
      },
      scales: {
        x: {
          type: "linear",
          min: timestampValue(spec.bounds?.start),
          max: timestampValue(spec.bounds?.end),
          grid: {
            color: alphaColor(colors.base300, 0.7),
          },
          ticks: {
            color: alphaColor(colors.baseContent, 0.65),
            callback: value => formatChartTime(value),
            maxTicksLimit: 6,
          },
        },
        y: {
          min: 0,
          max: yMax,
          ticks: {
            stepSize: Math.max(1, yMax / 4),
            precision: 0,
            color: alphaColor(colors.baseContent, 0.65),
          },
          grid: {
            color: alphaColor(colors.base300, 0.85),
          },
        },
      },
      plugins: {
        legend: {
          display: false,
        },
        tooltip: {
          callbacks: {
            title(items) {
              const raw = items[0]?.raw
              return raw?.timestamp ? formatChartDateTime(raw.timestamp) : ""
            },
            label(item) {
              const raw = item.raw || {}

              if (raw.kind) {
                return `${raw.icon}: ${raw.label}${raw.detail ? ` (${raw.detail})` : ""}`
              }

              return `${item.dataset.label}: ${raw.y}`
            },
          },
        },
        trafficLanes: {
          laneColor: alphaColor(colors.base300, 0.9),
          labelColor: alphaColor(colors.baseContent, 0.55),
        },
      },
    },
  }
}

function lineDataset(values, metric, label, color) {
  return {
    type: "line",
    label,
    data: values
      .filter(value => value.metric === metric)
      .map(value => ({
        x: timestampValue(value.timestamp),
        y: value.value,
        timestamp: value.timestamp,
        server: value.server,
      }))
      .filter(value => Number.isFinite(value.x)),
    borderColor: color,
    backgroundColor: color,
    borderWidth: 3,
    pointRadius: 3,
    pointHoverRadius: 5,
    tension: 0.35,
  }
}

function markerDataset(values, kind, label, y, colors) {
  const data = values
    .filter(value => value.kind === kind)
    .map(value => ({
      x: timestampValue(value.timestamp),
      y,
      timestamp: value.timestamp,
      kind: value.kind,
      severity: value.severity,
      icon: value.icon,
      label: value.label,
      detail: value.detail,
    }))
    .filter(value => Number.isFinite(value.x))

  return {
    type: "scatter",
    label,
    data,
    borderWidth: 2,
    pointRadius: 5,
    pointHoverRadius: 7,
    showLine: false,
    backgroundColor: data.map(value => markerColor(value, colors)),
    borderColor: data.map(value => markerColor(value, colors)),
  }
}

function markerColor(value, colors) {
  if (value.kind === "frame") {
    return colors.info
  }

  if (value.kind === "event") {
    return colors.warning
  }

  return alphaColor(colors.baseContent, 0.7)
}

function cssColor(style, name, fallback) {
  return canvasColor(style.getPropertyValue(name).trim(), fallback)
}

function canvasColor(value, fallback) {
  const probe = canvasColor.probe || document.createElement("canvas").getContext("2d")
  canvasColor.probe = probe
  probe.fillStyle = fallback
  probe.fillStyle = value || fallback
  return probe.fillStyle || fallback
}

function alphaColor(color, alpha) {
  const rgba = color.match(/^rgba?\(([^)]+)\)$/)

  if (rgba) {
    const [red, green, blue] = rgba[1].split(/\s*,\s*|\s+/).filter(Boolean)
    return `rgba(${red}, ${green}, ${blue}, ${alpha})`
  }

  if (/^#[0-9a-f]{6}$/i.test(color)) {
    const red = Number.parseInt(color.slice(1, 3), 16)
    const green = Number.parseInt(color.slice(3, 5), 16)
    const blue = Number.parseInt(color.slice(5, 7), 16)
    return `rgba(${red}, ${green}, ${blue}, ${alpha})`
  }

  return color
}

function timestampValue(value) {
  const timestamp = Date.parse(value)
  return Number.isFinite(timestamp) ? timestamp : undefined
}

function formatChartTime(value) {
  return new Intl.DateTimeFormat(undefined, {
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value))
}

function formatChartDateTime(value) {
  return new Intl.DateTimeFormat(undefined, {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).format(new Date(value))
}

function roundCoordinate(value) {
  return Number.parseFloat(value).toFixed(6)
}

function dispatchInput(input) {
  input.dispatchEvent(new Event("input", {bubbles: true}))
  input.dispatchEvent(new Event("change", {bubbles: true}))
}

function enhanceBackpexFormTabs(root = document) {
  const forms = Array.from(root.querySelectorAll ? root.querySelectorAll("#resource-form") : [])

  for (const form of forms) {
    if (form.dataset.backpexTabsEnhanced === "true" && form.querySelector(".backpex-form-tabs")) {
      continue
    }

    const panelContainer = form.querySelector(".card-body > div:first-child")
    if (!panelContainer) {
      continue
    }

    const fieldsets = Array.from(panelContainer.querySelectorAll(":scope > fieldset")).filter(
      fieldset => fieldset.querySelector("[data-field-name], input, select, textarea")
    )

    const labeledFieldsets = fieldsets.filter(fieldset => fieldset.querySelector("legend"))
    if (fieldsets.length < 2 || labeledFieldsets.length < 2) {
      continue
    }

    const tabs = document.createElement("div")
    tabs.className = "backpex-form-tabs"
    tabs.setAttribute("role", "tablist")
    tabs.setAttribute("aria-label", "Form sections")

    const activate = activeIndex => {
      fieldsets.forEach((fieldset, index) => {
        const active = index === activeIndex
        fieldset.hidden = !active
        fieldset.classList.toggle("backpex-form-tab-panel-active", active)
      })

      Array.from(tabs.children).forEach((tab, index) => {
        const active = index === activeIndex
        tab.classList.toggle("backpex-form-tab-active", active)
        tab.setAttribute("aria-selected", active ? "true" : "false")
        tab.tabIndex = active ? 0 : -1
      })
    }

    fieldsets.forEach((fieldset, index) => {
      const legend = fieldset.querySelector("legend")
      const label = (legend?.textContent || `Section ${index + 1}`).trim()

      if (legend) {
        legend.classList.add("sr-only")
      }

      const tab = document.createElement("button")
      tab.type = "button"
      tab.className = "backpex-form-tab"
      tab.textContent = label
      tab.setAttribute("role", "tab")
      tab.addEventListener("click", () => activate(index))
      tabs.appendChild(tab)
    })

    panelContainer.prepend(tabs)
    form.dataset.backpexTabsEnhanced = "true"
    activate(0)
  }
}

function scheduleBackpexFormTabsEnhancement() {
  window.requestAnimationFrame(() => enhanceBackpexFormTabs())
}

function enhanceSearchableSelects(root = document) {
  const selects = Array.from(
    root.querySelectorAll ? root.querySelectorAll("[data-searchable-select]") : []
  )

  for (const select of selects) {
    if (select.dataset.searchableSelectEnhanced === "true") {
      continue
    }

    const input = select.querySelector("[data-searchable-select-input]")
    const hiddenInput = select.querySelector("[data-searchable-select-value]")
    const options = select.querySelector(".backpex-searchable-select-options")
    const optionButtons = Array.from(select.querySelectorAll(".backpex-searchable-select-option"))
    const empty = select.querySelector(".backpex-searchable-select-empty")

    if (!input || !hiddenInput || !options || optionButtons.length === 0) {
      continue
    }

    let selectedLabel = input.value

    const open = () => {
      options.hidden = false
      input.setAttribute("aria-expanded", "true")
      filterOptions()
    }

    const close = () => {
      options.hidden = true
      input.setAttribute("aria-expanded", "false")
    }

    const filterOptions = () => {
      const query = input.value.trim().toLowerCase()
      let visibleCount = 0

      for (const option of optionButtons) {
        const optionText = option.textContent.trim().toLowerCase()
        const optionValue = String(option.dataset.value || "").toLowerCase()
        const visible = query === "" || optionText.includes(query) || optionValue.includes(query)

        option.hidden = !visible
        if (visible) {
          visibleCount += 1
        }
      }

      if (empty) {
        empty.hidden = visibleCount !== 0
      }
    }

    input.addEventListener("focus", open)
    input.addEventListener("input", () => {
      if (input.value !== selectedLabel) {
        hiddenInput.value = ""
        selectedLabel = ""
      }

      open()
    })

    input.addEventListener("blur", () => {
      window.setTimeout(() => {
        if (hiddenInput.value === "") {
          input.value = ""
        }
      }, 150)
    })

    input.addEventListener("keydown", event => {
      if (event.key === "Escape") {
        close()
      }
    })

    for (const option of optionButtons) {
      option.addEventListener("mousedown", event => {
        event.preventDefault()
        selectedLabel = option.querySelector("span")?.textContent.trim() || option.dataset.value || ""
        input.value = selectedLabel
        hiddenInput.value = option.dataset.value || ""
        dispatchInput(hiddenInput)
        close()
      })
    }

    document.addEventListener("mousedown", event => {
      if (!select.contains(event.target)) {
        close()
      }
    })

    select.dataset.searchableSelectEnhanced = "true"
  }
}

function scheduleSearchableSelectEnhancement() {
  window.requestAnimationFrame(() => enhanceSearchableSelects())
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {
    ...colocatedHooks,
    ...BackpexHooks,
    ...BackpexThemeSelector,
    GatewayLocationMap,
    TrafficGraphNavigator,
  },
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => {
  topbar.hide()
  applyStoredBackpexTheme()
  scheduleBackpexFormTabsEnhancement()
  scheduleSearchableSelectEnhancement()
})

window.addEventListener("DOMContentLoaded", scheduleBackpexFormTabsEnhancement)
window.addEventListener("DOMContentLoaded", scheduleSearchableSelectEnhancement)

new MutationObserver(() => {
  scheduleBackpexFormTabsEnhancement()
  scheduleSearchableSelectEnhancement()
}).observe(document.body, {
  childList: true,
  subtree: true,
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
