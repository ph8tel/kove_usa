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
import {hooks as colocatedHooks} from "phoenix-colocated/kove"
import topbar from "../vendor/topbar"

// Custom LiveView Hooks
const ScrollBottom = {
  mounted() { this.scrollToBottom() },
  updated() { this.scrollToBottom() },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

const Carousel = {
  mounted() {
    this.index = 0
    this.interval = null
    this.slides = this.el.querySelectorAll("[data-slide]")
    this.dots = this.el.querySelectorAll("[data-dot]")
    this.total = this.slides.length

    if (this.total > 1) {
      this.startAutoPlay()
    }
    this.showSlide(0)
    this.bindClicks()

    this.handleEvent("update-slides", ({slides}) => this.rebuildSlides(slides))
  },

  updated() {
    this.slides = this.el.querySelectorAll("[data-slide]")
    this.dots = this.el.querySelectorAll("[data-dot]")
    this.total = this.slides.length

    if (this.index >= this.total) this.index = 0
    this.showSlide(this.index)
    this.bindClicks()

    if (this.total > 1 && !this.interval) {
      this.startAutoPlay()
    } else if (this.total <= 1 && this.interval) {
      clearInterval(this.interval)
      this.interval = null
    }
  },

  destroyed() {
    if (this.interval) clearInterval(this.interval)
  },

  bindClicks() {
    const prevBtn = this.el.querySelector("[data-prev]")
    const nextBtn = this.el.querySelector("[data-next]")
    if (prevBtn) prevBtn.onclick = (e) => { e.preventDefault(); this.prev(); this.startAutoPlay() }
    if (nextBtn) nextBtn.onclick = (e) => { e.preventDefault(); this.next(); this.startAutoPlay() }
    this.dots.forEach((dot, idx) => {
      dot.onclick = (e) => { e.preventDefault(); this.goTo(idx) }
    })
  },

  startAutoPlay() {
    if (this.interval) clearInterval(this.interval)
    this.interval = setInterval(() => this.next(), 5000)
  },

  next() {
    this.index = (this.index + 1) % this.total
    this.showSlide(this.index)
  },

  prev() {
    this.index = (this.index - 1 + this.total) % this.total
    this.showSlide(this.index)
  },

  goTo(i) {
    this.index = i
    this.showSlide(i)
    this.startAutoPlay()
  },

  showSlide(i) {
    this.slides.forEach((slide, idx) => {
      slide.style.opacity = idx === i ? "1" : "0"
      slide.style.zIndex = idx === i ? "1" : "0"
    })
    this.dots.forEach((dot, idx) => {
      if (idx === i) {
        dot.classList.add("bg-primary")
        dot.classList.remove("bg-white/50")
      } else {
        dot.classList.remove("bg-primary")
        dot.classList.add("bg-white/50")
      }
    })
  },

  rebuildSlides(slides) {
    if (this.interval) { clearInterval(this.interval); this.interval = null }

    // Clear all dynamic content
    this.el.querySelectorAll("[data-slide]").forEach(el => el.remove())
    this.el.querySelectorAll("[data-prev],[data-next]").forEach(el => el.remove())
    const oldDotBar = this.el.querySelector("[data-dotbar]")
    if (oldDotBar) oldDotBar.remove()

    if (slides.length === 0) {
      const empty = document.createElement("div")
      empty.setAttribute("data-slide", "")
      empty.className = "absolute inset-0 flex flex-col items-center justify-center text-base-content/30 transition-opacity duration-500"
      empty.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="size-24" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="m2.25 15.75 5.159-5.159a2.25 2.25 0 0 1 3.182 0l5.159 5.159m-1.5-1.5 1.409-1.409a2.25 2.25 0 0 1 3.182 0l2.909 2.909M3.75 21h16.5A2.25 2.25 0 0 0 22.5 18.75V5.25A2.25 2.25 0 0 0 20.25 3H3.75A2.25 2.25 0 0 0 1.5 5.25v13.5A2.25 2.25 0 0 0 3.75 21Z"/></svg><p class="mt-2 text-sm">No bike photos yet</p>`
      this.el.appendChild(empty)
    } else {
      slides.forEach((slide) => {
        const div = document.createElement("div")
        div.setAttribute("data-slide", "")
        div.className = "absolute inset-0 transition-opacity duration-500 opacity-0"
        div.innerHTML = `<img src="${slide.url}" alt="${slide.label}" class="w-full h-full object-cover"/><div class="absolute bottom-8 left-4 bg-black/50 text-white text-xs px-2 py-1 rounded">${slide.label}</div>`
        this.el.appendChild(div)
      })
    }

    if (slides.length > 1) {
      const prevBtn = document.createElement("button")
      prevBtn.setAttribute("data-prev", "")
      prevBtn.className = "absolute left-2 top-1/2 -translate-y-1/2 btn btn-circle btn-sm btn-ghost bg-black/30 text-white opacity-0 group-hover:opacity-100 transition-opacity z-10"
      prevBtn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="size-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M12.79 5.23a.75.75 0 01-.02 1.06L8.832 10l3.938 3.71a.75.75 0 11-1.04 1.08l-4.5-4.25a.75.75 0 010-1.08l4.5-4.25a.75.75 0 011.06.02z" clip-rule="evenodd"/></svg>`
      this.el.appendChild(prevBtn)

      const nextBtn = document.createElement("button")
      nextBtn.setAttribute("data-next", "")
      nextBtn.className = "absolute right-2 top-1/2 -translate-y-1/2 btn btn-circle btn-sm btn-ghost bg-black/30 text-white opacity-0 group-hover:opacity-100 transition-opacity z-10"
      nextBtn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="size-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z" clip-rule="evenodd"/></svg>`
      this.el.appendChild(nextBtn)

      const dotBar = document.createElement("div")
      dotBar.setAttribute("data-dotbar", "")
      dotBar.className = "absolute bottom-2 left-1/2 -translate-x-1/2 flex gap-1.5 z-10"
      slides.forEach(() => {
        const dot = document.createElement("button")
        dot.setAttribute("data-dot", "")
        dot.className = "size-2.5 rounded-full transition-colors bg-white/50"
        dotBar.appendChild(dot)
      })
      this.el.appendChild(dotBar)
    }

    // Re-query and reset
    this.slides = this.el.querySelectorAll("[data-slide]")
    this.dots = this.el.querySelectorAll("[data-dot]")
    this.total = this.slides.length
    this.index = 0
    this.showSlide(0)
    this.bindClicks()
    if (this.total > 1) this.startAutoPlay()
  }
}

const Hooks = { ...colocatedHooks, ScrollBottom, Carousel }

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

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
    window.addEventListener("keyup", e => keyDown = null)
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

