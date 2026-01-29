// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// LiveView hooks for custom JavaScript functionality
let Hooks = {}

// Example: Timer hook for smooth countdown display
Hooks.Timer = {
  mounted() {
    this.handleEvent("tick", ({remaining}) => {
      this.el.innerText = this.formatTime(remaining)
    })
  },
  formatTime(seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }
}

// Example: Score slider hook for smooth input
Hooks.ScoreSlider = {
  mounted() {
    const slider = this.el.querySelector('input[type="range"]')
    const display = this.el.querySelector('[data-score-display]')

    if (slider && display) {
      slider.addEventListener('input', (e) => {
        display.innerText = e.target.value
      })
    }
  }
}

// Example: Copy to clipboard hook
Hooks.CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", () => {
      const text = this.el.dataset.copyText
      navigator.clipboard.writeText(text).then(() => {
        this.pushEvent("copied", {})
      })
    })
  }
}

// Duration picker hook for client-side increment/decrement
Hooks.DurationPicker = {
  mounted() {
    this.duration = parseInt(this.el.dataset.duration) || 120
    this.min = 30
    this.max = 480

    this.formattedDisplay = this.el.querySelector('[data-display="formatted"]')
    this.minutesDisplay = this.el.querySelector('[data-display="minutes"]')
    this.hiddenInput = this.el.querySelector('[data-input="duration"]')

    this.el.querySelector('[data-action="decrement"]').addEventListener("click", () => {
      this.duration = Math.max(this.duration - 5, this.min)
      this.updateDisplay()
    })

    this.el.querySelector('[data-action="increment"]').addEventListener("click", () => {
      this.duration = Math.min(this.duration + 5, this.max)
      this.updateDisplay()
    })
  },

  updateDisplay() {
    const hours = Math.floor(this.duration / 60)
    const mins = this.duration % 60

    let formatted
    if (hours === 0) {
      formatted = `${mins} min`
    } else if (mins === 0) {
      formatted = `${hours} hr`
    } else {
      formatted = `${hours} hr ${mins} min`
    }

    this.formattedDisplay.innerText = formatted
    this.minutesDisplay.innerText = this.duration
    this.hiddenInput.value = this.duration
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Copy to clipboard event handler
window.addEventListener("phx:copy", (event) => {
  const input = event.target
  if (input && input.value) {
    navigator.clipboard.writeText(input.value).then(() => {
      // Show brief feedback by changing button text
      const button = input.parentElement.querySelector("button")
      if (button) {
        const originalText = button.innerText
        button.innerText = "Copied!"
        setTimeout(() => { button.innerText = originalText }, 2000)
      }
    })
  }
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
