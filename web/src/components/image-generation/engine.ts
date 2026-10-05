import type { PresetMode } from "./presets"
import { COMPOSITE_FRAGMENT_SRC, VERTEX_SRC, cellFragmentSrc } from "./shaders"

const MAX_DPR = 2
const REF_DIM = 320
const FRAME_MS = 1000 / 60
const HIDE_MS = 300
const MAX_CONTEXTS = 8

type Phase = "idle" | "reveal" | "visible" | "hide"

export type EngineOptions = {
  canvas: HTMLCanvasElement
  preset: PresetMode
  image?: string | null
  onSettle?: (settled: boolean) => void
}

export type Engine = {
  setPreset: (preset: PresetMode) => void
  setImage: (src: string | null) => void
  setReveal: (reveal: boolean) => void
  setVisible: (visible: boolean) => void
  resize: () => void
  dispose: () => void
}

const imageCache = new Map<string, Promise<HTMLImageElement>>()
const engineCanvases = new WeakSet<HTMLCanvasElement>()
let liveContexts = 0

let webgl2Supported: boolean | null = null

export function supportsWebGL2(): boolean {
  if (webgl2Supported !== null) return webgl2Supported
  if (typeof document === "undefined") return false
  try {
    const probe = document.createElement("canvas").getContext("webgl2")
    webgl2Supported = !!probe
    probe?.getExtension("WEBGL_lose_context")?.loseContext()
  } catch {
    webgl2Supported = false
  }
  return webgl2Supported
}

export function loadImage(src: string): Promise<HTMLImageElement> {
  const cached = imageCache.get(src)
  if (cached) return cached
  const pending = new Promise<HTMLImageElement>((resolve, reject) => {
    const img = new Image()
    img.crossOrigin = "anonymous"
    img.decoding = "async"
    img.onload = () => resolve(img)
    img.onerror = () => reject(new Error(`img-fx: failed to load ${src}`))
    img.src = src
  })
  pending.catch(() => imageCache.delete(src))
  imageCache.set(src, pending)
  return pending
}

function hexToRgb(hex: string): [number, number, number] {
  const clean = hex.replace("#", "")
  const full = clean.length === 3 ? clean.replace(/./g, (c) => c + c) : clean
  const n = Number.parseInt(full, 16)
  return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255]
}

function easeOutCubic(t: number): number {
  const p = 1 - t
  return 1 - p * p * p
}

function compile(gl: WebGL2RenderingContext, type: number, src: string): WebGLShader | null {
  const shader = gl.createShader(type)
  if (!shader) return null
  gl.shaderSource(shader, src)
  gl.compileShader(shader)
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    console.error(`img-fx shader: ${gl.getShaderInfoLog(shader)}`)
    gl.deleteShader(shader)
    return null
  }
  return shader
}

function link(gl: WebGL2RenderingContext, fragmentSrc: string): WebGLProgram | null {
  const vs = compile(gl, gl.VERTEX_SHADER, VERTEX_SRC)
  const fs = compile(gl, gl.FRAGMENT_SHADER, fragmentSrc)
  if (!vs || !fs) return null
  const program = gl.createProgram()
  if (!program) return null
  gl.attachShader(program, vs)
  gl.attachShader(program, fs)
  gl.linkProgram(program)
  gl.deleteShader(vs)
  gl.deleteShader(fs)
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.error(`img-fx program: ${gl.getProgramInfoLog(program)}`)
    gl.deleteProgram(program)
    return null
  }
  return program
}

function uniformMap(gl: WebGL2RenderingContext, program: WebGLProgram): Map<string, WebGLUniformLocation> {
  const map = new Map<string, WebGLUniformLocation>()
  const count = gl.getProgramParameter(program, gl.ACTIVE_UNIFORMS) as number
  for (let i = 0; i < count; i++) {
    const info = gl.getActiveUniform(program, i)
    if (!info) continue
    const location = gl.getUniformLocation(program, info.name)
    if (location) map.set(info.name.replace("[0]", ""), location)
  }
  return map
}

const running = new Set<() => void>()
let rafId = 0
let lastFrame = 0

function loop(now: number) {
  rafId = running.size > 0 ? requestAnimationFrame(loop) : 0
  if (running.size === 0) return
  if (now - lastFrame < FRAME_MS - 0.5) return
  lastFrame = now
  for (const tick of running) tick()
}

function schedule(tick: () => void) {
  running.add(tick)
  if (!rafId) {
    lastFrame = 0
    rafId = requestAnimationFrame(loop)
  }
}

function unschedule(tick: () => void) {
  running.delete(tick)
  if (running.size === 0 && rafId) {
    cancelAnimationFrame(rafId)
    rafId = 0
  }
}

export function createEngine(options: EngineOptions): Engine | null {
  if (liveContexts >= MAX_CONTEXTS) return null

  const { canvas, onSettle } = options
  const gl = canvas.getContext("webgl2", {
    alpha: true,
    antialias: false,
    depth: false,
    stencil: false,
    premultipliedAlpha: false,
    preserveDrawingBuffer: false,
    powerPreference: "low-power",
  })
  if (!gl) return null
  liveContexts += 1
  engineCanvases.add(canvas)

  let preset = options.preset
  let cellProgram: WebGLProgram | null = null
  let cellUniforms = new Map<string, WebGLUniformLocation>()
  let compositeProgram: WebGLProgram | null = null
  let compositeUniforms = new Map<string, WebGLUniformLocation>()
  let vao: WebGLVertexArrayObject | null = null

  let cellTexture: WebGLTexture | null = null
  let framebuffer: WebGLFramebuffer | null = null
  let imageTexture: WebGLTexture | null = null
  let imageEl: HTMLImageElement | null = null
  let imageSrc: string | null = options.image ?? null
  let imageToken = 0

  let dpr = 1
  let cssWidth = 0
  let cssHeight = 0
  let gridX = 2
  let gridY = 2
  let presetDirty = true
  let sizeDirty = true

  let time = Math.random() * 1000
  let lastTick = 0
  let phase: Phase = "idle"
  let phaseStart = 0
  let seed = Math.random() * 512
  let settled = false
  let visible = true
  let contextLost = false
  let disposed = false

  function buildPrograms(): boolean {
    cellProgram = link(gl!, cellFragmentSrc(preset.effectIndex))
    compositeProgram = link(gl!, COMPOSITE_FRAGMENT_SRC)
    if (!cellProgram || !compositeProgram) return false
    cellUniforms = uniformMap(gl!, cellProgram)
    compositeUniforms = uniformMap(gl!, compositeProgram)
    vao = gl!.createVertexArray()
    return true
  }

  function allocCellTarget() {
    if (cellTexture) gl!.deleteTexture(cellTexture)
    cellTexture = gl!.createTexture()
    gl!.bindTexture(gl!.TEXTURE_2D, cellTexture)
    gl!.texStorage2D(gl!.TEXTURE_2D, 1, gl!.RGBA8, gridX, gridY)
    gl!.texParameteri(gl!.TEXTURE_2D, gl!.TEXTURE_MIN_FILTER, gl!.NEAREST)
    gl!.texParameteri(gl!.TEXTURE_2D, gl!.TEXTURE_MAG_FILTER, gl!.NEAREST)
    gl!.texParameteri(gl!.TEXTURE_2D, gl!.TEXTURE_WRAP_S, gl!.CLAMP_TO_EDGE)
    gl!.texParameteri(gl!.TEXTURE_2D, gl!.TEXTURE_WRAP_T, gl!.CLAMP_TO_EDGE)
    if (!framebuffer) framebuffer = gl!.createFramebuffer()
    gl!.bindFramebuffer(gl!.FRAMEBUFFER, framebuffer)
    gl!.framebufferTexture2D(gl!.FRAMEBUFFER, gl!.COLOR_ATTACHMENT0, gl!.TEXTURE_2D, cellTexture, 0)
    gl!.bindFramebuffer(gl!.FRAMEBUFFER, null)
  }

  function uploadImage(img: HTMLImageElement) {
    if (imageTexture) gl!.deleteTexture(imageTexture)
    imageTexture = gl!.createTexture()
    gl!.bindTexture(gl!.TEXTURE_2D, imageTexture)
    gl!.pixelStorei(gl!.UNPACK_FLIP_Y_WEBGL, true)
    gl!.texImage2D(gl!.TEXTURE_2D, 0, gl!.RGBA, gl!.RGBA, gl!.UNSIGNED_BYTE, img)
    gl!.pixelStorei(gl!.UNPACK_FLIP_Y_WEBGL, false)
    gl!.texParameteri(gl!.TEXTURE_2D, gl!.TEXTURE_WRAP_S, gl!.CLAMP_TO_EDGE)
    gl!.texParameteri(gl!.TEXTURE_2D, gl!.TEXTURE_WRAP_T, gl!.CLAMP_TO_EDGE)
    gl!.texParameteri(gl!.TEXTURE_2D, gl!.TEXTURE_MIN_FILTER, gl!.LINEAR_MIPMAP_LINEAR)
    gl!.texParameteri(gl!.TEXTURE_2D, gl!.TEXTURE_MAG_FILTER, gl!.LINEAR)
    gl!.generateMipmap(gl!.TEXTURE_2D)
    imageEl = img
  }

  function measure(): boolean {
    const rect = canvas.getBoundingClientRect()
    const nextDpr = Math.min(window.devicePixelRatio || 1, MAX_DPR)
    const w = Math.max(1, Math.round(rect.width))
    const h = Math.max(1, Math.round(rect.height))
    if (w === cssWidth && h === cssHeight && nextDpr === dpr) return false
    cssWidth = w
    cssHeight = h
    dpr = nextDpr
    canvas.width = Math.max(1, Math.round(w * dpr))
    canvas.height = Math.max(1, Math.round(h * dpr))
    const base = 6 + preset.cellSize * 74
    const nextGridX = Math.max(2, Math.floor((base * w) / REF_DIM))
    const nextGridY = Math.max(2, Math.floor((base * h) / REF_DIM))
    if (nextGridX !== gridX || nextGridY !== gridY || !cellTexture) {
      gridX = nextGridX
      gridY = nextGridY
      allocCellTarget()
    }
    return true
  }

  function uploadPresetUniforms() {
    const p = preset
    gl!.useProgram(cellProgram)
    const cu = cellUniforms
    const colors = p.colors.map(hexToRgb)
    for (let i = 0; i < 5; i++) {
      const c = colors[i]
      const loc = cu.get(`u_color${i + 1}`)
      if (loc) gl!.uniform3f(loc, c[0], c[1], c[2])
      const alphaLoc = cu.get(`u_alpha${i + 1}`)
      if (alphaLoc) gl!.uniform1f(alphaLoc, p.alphas[i])
    }
    const setCell = (name: string, value: number) => {
      const loc = cu.get(name)
      if (loc) gl!.uniform1f(loc, value)
    }
    setCell("u_speed", p.speed)
    setCell("u_intensity", p.intensity)
    setCell("u_scale", p.scale)
    setCell("u_direction", (p.direction * Math.PI) / 180)
    setCell("u_distortion", p.distortion)
    setCell("u_complexity", p.complexity)
    setCell("u_shape", p.shape)
    setCell("u_flicker", p.flicker)
    setCell("u_blur", p.blur)
    const sweepLoc = cu.get("u_sweepEase")
    if (sweepLoc) gl!.uniform1i(sweepLoc, Math.floor(p.sweepEase))

    gl!.useProgram(compositeProgram)
    const xu = compositeUniforms
    const setComposite = (name: string, value: number) => {
      const loc = xu.get(name)
      if (loc) gl!.uniform1f(loc, value)
    }
    const bg = hexToRgb(p.cardBg)
    const bgLoc = xu.get("u_cardBg")
    if (bgLoc) gl!.uniform3f(bgLoc, bg[0], bg[1], bg[2])
    const maskColor = hexToRgb(p.colors[p.reveal.maskColorIndex] ?? p.colors[3])
    const maskLoc = xu.get("u_maskColor")
    if (maskLoc) gl!.uniform3f(maskLoc, maskColor[0], maskColor[1], maskColor[2])
    setComposite("u_gap", p.gap)
    setComposite("u_dotOpacity", p.dotOpacity)
    setComposite("u_fillOpacity", p.fillOpacity)
    setComposite("u_hlScale", p.hlScale)
    setComposite("u_highlight", p.highlight)
    setComposite("u_edgeFade", p.edgeFade)
    setComposite("u_fadeStr", p.fadeStr)
    setComposite("u_vignette", p.vignette)
    setComposite("u_vigOpacity", p.vigOpacity)
    setComposite("u_shaderOpacity", p.shaderOpacity)
    setComposite("u_colorAlpha", p.alphas.reduce((a, b) => a + b, 0) / p.alphas.length)
    setComposite("u_maskSoftness", p.reveal.softness)
    setComposite("u_maskScale", p.scale)
    setComposite("u_maskFlicker", p.reveal.maskMode === "gradientSweep" ? p.flicker : 0)
    const modeLoc = xu.get("u_maskMode")
    if (modeLoc) gl!.uniform1i(modeLoc, p.reveal.maskMode === "gradientSweep" ? 1 : 0)
    const cellsLoc = xu.get("u_cells")
    if (cellsLoc) gl!.uniform1i(cellsLoc, 0)
    const imageLoc = xu.get("u_image")
    if (imageLoc) gl!.uniform1i(imageLoc, 1)
  }

  function coverRect(): [number, number, number, number] {
    if (!imageEl || cssWidth === 0 || cssHeight === 0) return [1, 1, 0, 0]
    const canvasAspect = cssWidth / cssHeight
    const imageAspect = imageEl.naturalWidth / imageEl.naturalHeight
    if (imageAspect > canvasAspect) {
      const fx = canvasAspect / imageAspect
      return [fx, 1, (1 - fx) / 2, 0]
    }
    const fy = imageAspect / canvasAspect
    return [1, fy, 0, (1 - fy) / 2]
  }

  function markSettled(next: boolean) {
    if (settled === next) return
    settled = next
    onSettle?.(next)
    sync()
  }

  function render(now: number) {
    if (!gl || contextLost || disposed) return
    const delta = lastTick === 0 ? 0 : Math.min((now - lastTick) / 1000, 0.1)
    lastTick = now
    time += delta

    if (sizeDirty) {
      measure()
      sizeDirty = false
    }
    if (presetDirty) {
      uploadPresetUniforms()
      presetDirty = false
    }

    const elapsed = (now - phaseStart) / 1000
    if (phase === "reveal" && elapsed >= preset.reveal.duration) phase = "visible"

    let maskProgress = 0
    let pixProgress = 0
    let imageMix = 0
    if (phase === "reveal") {
      maskProgress = easeOutCubic(Math.min(elapsed / preset.reveal.duration, 1))
      pixProgress = easeOutCubic(Math.min(elapsed / preset.reveal.pixDuration, 1))
      imageMix = 1
    } else if (phase === "visible") {
      maskProgress = 1
      pixProgress = 1
      imageMix = 1
    } else if (phase === "hide") {
      maskProgress = 1
      pixProgress = 1
      imageMix = Math.max(0, 1 - ((now - phaseStart) / HIDE_MS))
      if (imageMix <= 0) phase = "idle"
    }

    const hasImage = imageTexture != null && imageMix > 0

    gl.bindVertexArray(vao)

    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer)
    gl.viewport(0, 0, gridX, gridY)
    gl.useProgram(cellProgram)
    const gridLoc = cellUniforms.get("u_grid")
    if (gridLoc) gl.uniform2f(gridLoc, gridX, gridY)
    const aspectLoc = cellUniforms.get("u_aspect")
    if (aspectLoc) gl.uniform1f(aspectLoc, cssWidth / Math.max(cssHeight, 1))
    const timeLoc = cellUniforms.get("u_time")
    if (timeLoc) gl.uniform1f(timeLoc, time)
    gl.drawArrays(gl.TRIANGLES, 0, 3)

    gl.bindFramebuffer(gl.FRAMEBUFFER, null)
    gl.viewport(0, 0, canvas.width, canvas.height)
    gl.useProgram(compositeProgram)
    gl.activeTexture(gl.TEXTURE0)
    gl.bindTexture(gl.TEXTURE_2D, cellTexture)
    gl.activeTexture(gl.TEXTURE1)
    gl.bindTexture(gl.TEXTURE_2D, imageTexture)

    const xu = compositeUniforms
    const set1f = (name: string, value: number) => {
      const loc = xu.get(name)
      if (loc) gl.uniform1f(loc, value)
    }
    const resLoc = xu.get("u_resolution")
    if (resLoc) gl.uniform2f(resLoc, canvas.width, canvas.height)
    const gridLoc2 = xu.get("u_grid")
    if (gridLoc2) gl.uniform2f(gridLoc2, gridX, gridY)
    set1f("u_dpr", dpr)
    set1f("u_maskProgress", maskProgress)
    set1f("u_pixProgress", pixProgress)
    set1f("u_imageMix", imageMix)
    set1f("u_seed", seed)

    const flickerT = time * Math.max(preset.speed, 2) * 1.6
    const rawStep = Math.floor(flickerT)
    const fz = flickerT - rawStep
    const clockLoc = xu.get("u_flickerClock")
    if (clockLoc) gl.uniform3f(clockLoc, rawStep % 1024, (rawStep + 1) % 1024, fz * fz * (3 - 2 * fz))

    const rect = coverRect()
    const rectLoc = xu.get("u_imageRect")
    if (rectLoc) gl.uniform4f(rectLoc, rect[0], rect[1], rect[2], rect[3])
    const sourcePerCell = imageEl ? (imageEl.naturalWidth * rect[0]) / gridX : 1
    set1f("u_imageLod", Math.log2(Math.max(1, sourcePerCell)))
    const hasLoc = xu.get("u_hasImage")
    if (hasLoc) gl.uniform1i(hasLoc, hasImage ? 1 : 0)

    gl.drawArrays(gl.TRIANGLES, 0, 3)
    gl.bindVertexArray(null)

    // A fully revealed frame is pixel-identical to the source image, so the
    // component swaps in a plain <img> and the GPU work stops here.
    markSettled(phase === "visible" && imageTexture != null)
  }

  const tick = () => {
    if (!visible || contextLost || disposed || settled) return
    render(performance.now())
  }

  function sync() {
    const shouldRun = visible && !contextLost && !disposed && !settled
    if (shouldRun) {
      schedule(tick)
    } else {
      unschedule(tick)
      lastTick = 0
    }
  }

  const onContextLost = (event: Event) => {
    event.preventDefault()
    contextLost = true
    sync()
  }

  const onContextRestored = () => {
    contextLost = false
    if (!buildPrograms()) return
    presetDirty = true
    sizeDirty = true
    cellTexture = null
    framebuffer = null
    imageTexture = null
    if (imageEl) uploadImage(imageEl)
    sync()
  }

  canvas.addEventListener("webglcontextlost", onContextLost)
  canvas.addEventListener("webglcontextrestored", onContextRestored)

  if (!buildPrograms()) {
    canvas.removeEventListener("webglcontextlost", onContextLost)
    canvas.removeEventListener("webglcontextrestored", onContextRestored)
    liveContexts -= 1
    return null
  }
  measure()
  uploadPresetUniforms()
  presetDirty = false

  function applyImage(src: string | null) {
    imageSrc = src
    const token = ++imageToken
    if (!src) {
      imageEl = null
      if (imageTexture) {
        gl!.deleteTexture(imageTexture)
        imageTexture = null
      }
      return
    }
    loadImage(src)
      .then((img) => {
        if (disposed || token !== imageToken) return
        uploadImage(img)
        markSettled(false)
        sync()
      })
      .catch(() => {})
  }

  applyImage(imageSrc)
  sync()

  return {
    setPreset(next) {
      preset = next
      presetDirty = true
      sizeDirty = true
      if (cellProgram) gl!.deleteProgram(cellProgram)
      if (compositeProgram) gl!.deleteProgram(compositeProgram)
      if (vao) gl!.deleteVertexArray(vao)
      if (!buildPrograms()) return
      markSettled(false)
      sync()
    },
    setImage(src) {
      if (src === imageSrc) return
      markSettled(false)
      applyImage(src)
      sync()
    },
    setReveal(reveal) {
      const now = performance.now()
      if (reveal) {
        if (phase === "reveal" || phase === "visible") return
        seed = Math.random() * 512
        phase = "reveal"
        phaseStart = now
        markSettled(false)
      } else {
        if (phase === "idle" || phase === "hide") return
        phase = "hide"
        phaseStart = now
        markSettled(false)
      }
      sync()
    },
    setVisible(next) {
      if (visible === next) return
      visible = next
      sync()
    },
    resize() {
      sizeDirty = true
      markSettled(false)
      sync()
    },
    dispose() {
      disposed = true
      unschedule(tick)
      canvas.removeEventListener("webglcontextlost", onContextLost)
      canvas.removeEventListener("webglcontextrestored", onContextRestored)
      if (cellTexture) gl!.deleteTexture(cellTexture)
      if (imageTexture) gl!.deleteTexture(imageTexture)
      if (framebuffer) gl!.deleteFramebuffer(framebuffer)
      if (vao) gl!.deleteVertexArray(vao)
      if (cellProgram) gl!.deleteProgram(cellProgram)
      if (compositeProgram) gl!.deleteProgram(compositeProgram)
      engineCanvases.delete(canvas)
      liveContexts -= 1
      // Release the context only once the canvas is really gone. React removes
      // the node after effect cleanup, and a strict-mode remount reuses the same
      // canvas — getContext would then hand back the permanently lost context.
      setTimeout(() => {
        if (!canvas.isConnected && !engineCanvases.has(canvas)) {
          gl!.getExtension("WEBGL_lose_context")?.loseContext()
        }
      }, 0)
    },
  }
}
