export type PresetName = "pixels-organic" | "pixels-mechanic" | "sweep-gradient"

export type MaskMode = "shaderColor" | "gradientSweep"

export type PresetMode = {
  effectIndex: 11 | 22 | 25
  colors: [string, string, string, string, string]
  alphas: [number, number, number, number, number]
  cardBg: string
  cellSize: number
  gap: number
  dotOpacity: number
  fillOpacity: number
  edgeFade: number
  fadeStr: number
  hlScale: number
  direction: number
  speed: number
  intensity: number
  scale: number
  softness: number
  distortion: number
  complexity: number
  shape: number
  flicker: number
  blur: number
  highlight: number
  vignette: number
  vigOpacity: number
  shaderOpacity: number
  sweepEase: number
  reveal: {
    duration: number
    pixDuration: number
    maskMode: MaskMode
    maskColorIndex: number
    softness: number
  }
}

export type Preset = { dark: PresetMode; light: PresetMode }

const pixelMosaic = {
  cellSize: 0.22,
  gap: 0.14,
  dotOpacity: 0.68,
  hlScale: 0.8,
  edgeFadeDark: 24,
  edgeFadeLight: 20,
  fadeStr: 1,
}

export const PRESETS: Record<PresetName, Preset> = {
  "pixels-organic": {
    dark: {
      effectIndex: 22,
      colors: ["#0f0f0f", "#4a4949", "#b9b9b9", "#0f0f0f", "#d8d8d8"],
      alphas: [1, 1, 1, 1, 1],
      cardBg: "#0f0f0f",
      cellSize: pixelMosaic.cellSize,
      gap: pixelMosaic.gap,
      dotOpacity: pixelMosaic.dotOpacity,
      fillOpacity: 0.44,
      edgeFade: pixelMosaic.edgeFadeDark,
      fadeStr: pixelMosaic.fadeStr,
      hlScale: pixelMosaic.hlScale,
      direction: 0,
      speed: 0.3,
      intensity: 1,
      scale: 1,
      softness: 0.76,
      distortion: 0.3,
      complexity: 0.2,
      shape: 0.52,
      flicker: 0,
      blur: 1,
      highlight: 0.2,
      vignette: 0.26,
      vigOpacity: 1,
      shaderOpacity: 1,
      sweepEase: 0,
      reveal: { duration: 3, pixDuration: 2.65, maskMode: "shaderColor", maskColorIndex: 3, softness: 0.5 },
    },
    light: {
      effectIndex: 22,
      colors: ["#e3e3e3", "#ffffff", "#f5f5f5", "#f5f5f5", "#080808"],
      alphas: [1, 1, 1, 1, 1],
      cardBg: "#f5f5f5",
      cellSize: pixelMosaic.cellSize,
      gap: pixelMosaic.gap,
      dotOpacity: pixelMosaic.dotOpacity,
      fillOpacity: 0.18,
      edgeFade: pixelMosaic.edgeFadeLight,
      fadeStr: pixelMosaic.fadeStr,
      hlScale: pixelMosaic.hlScale,
      direction: 25,
      speed: 0.3,
      intensity: 0.85,
      scale: 1,
      softness: 0.76,
      distortion: 0.3,
      complexity: 0.2,
      shape: 0.52,
      flicker: 0,
      blur: 1,
      highlight: 0.7,
      vignette: 0,
      vigOpacity: 0,
      shaderOpacity: 1,
      sweepEase: 0,
      reveal: { duration: 3, pixDuration: 2.55, maskMode: "shaderColor", maskColorIndex: 3, softness: 0.5 },
    },
  },
  "pixels-mechanic": {
    dark: {
      effectIndex: 11,
      colors: ["#949494", "#2d2d2d", "#333333", "#3a3a3a", "#0b0b0b"],
      alphas: [1, 1, 1, 1, 1],
      cardBg: "#0f0f0f",
      cellSize: pixelMosaic.cellSize,
      gap: pixelMosaic.gap,
      dotOpacity: pixelMosaic.dotOpacity,
      fillOpacity: 0.44,
      edgeFade: pixelMosaic.edgeFadeDark,
      fadeStr: pixelMosaic.fadeStr,
      hlScale: pixelMosaic.hlScale,
      direction: 0,
      speed: 0.7,
      intensity: 1,
      scale: 1.4,
      softness: 0.76,
      distortion: 0.3,
      complexity: 0.2,
      shape: 0.52,
      flicker: 0.5,
      blur: 1,
      highlight: 0.32,
      vignette: 0.26,
      vigOpacity: 1,
      shaderOpacity: 1,
      sweepEase: 0,
      reveal: { duration: 3, pixDuration: 2.65, maskMode: "shaderColor", maskColorIndex: 3, softness: 0.5 },
    },
    light: {
      effectIndex: 11,
      colors: ["#e0e0e0", "#fdfdfd", "#f2f2f2", "#0a0a0a", "#dcdcdc"],
      alphas: [1, 1, 1, 1, 1],
      cardBg: "#f5f5f5",
      cellSize: pixelMosaic.cellSize,
      gap: pixelMosaic.gap,
      dotOpacity: pixelMosaic.dotOpacity,
      fillOpacity: 0.18,
      edgeFade: pixelMosaic.edgeFadeLight,
      fadeStr: pixelMosaic.fadeStr,
      hlScale: pixelMosaic.hlScale,
      direction: 25,
      speed: 0.55,
      intensity: 0.85,
      scale: 0.9,
      softness: 0.76,
      distortion: 0.3,
      complexity: 0.2,
      shape: 0.52,
      flicker: 0.5,
      blur: 1,
      highlight: 0.92,
      vignette: 0,
      vigOpacity: 0,
      shaderOpacity: 1,
      sweepEase: 0,
      reveal: { duration: 3, pixDuration: 2.6, maskMode: "shaderColor", maskColorIndex: 2, softness: 0.5 },
    },
  },
  "sweep-gradient": {
    dark: {
      effectIndex: 25,
      colors: ["#0f0f0f", "#0f0f0f", "#282828", "#3a3a3a", "#525252"],
      alphas: [1, 1, 1, 1, 1],
      cardBg: "#0f0f0f",
      cellSize: pixelMosaic.cellSize,
      gap: pixelMosaic.gap,
      dotOpacity: pixelMosaic.dotOpacity,
      fillOpacity: 0.44,
      edgeFade: pixelMosaic.edgeFadeDark,
      fadeStr: pixelMosaic.fadeStr,
      hlScale: pixelMosaic.hlScale,
      direction: 0,
      speed: 2.65,
      intensity: 1,
      scale: 1,
      softness: 0.76,
      distortion: 0.3,
      complexity: 0.2,
      shape: 0.52,
      flicker: 0.5,
      blur: 1,
      highlight: 0.32,
      vignette: 0.26,
      vigOpacity: 1,
      shaderOpacity: 1,
      sweepEase: 1,
      reveal: { duration: 3, pixDuration: 2.65, maskMode: "gradientSweep", maskColorIndex: 3, softness: 0.5 },
    },
    light: {
      effectIndex: 25,
      colors: ["#f5f5f5", "#f5f5f5", "#ededed", "#eaeaea", "#d2d2d2"],
      alphas: [1, 1, 1, 1, 1],
      cardBg: "#f5f5f5",
      cellSize: pixelMosaic.cellSize,
      gap: pixelMosaic.gap,
      dotOpacity: pixelMosaic.dotOpacity,
      fillOpacity: 0.18,
      edgeFade: pixelMosaic.edgeFadeLight,
      fadeStr: pixelMosaic.fadeStr,
      hlScale: pixelMosaic.hlScale,
      direction: 0,
      speed: 2.65,
      intensity: 0.85,
      scale: 1,
      softness: 0.76,
      distortion: 0.3,
      complexity: 0.2,
      shape: 0.52,
      flicker: 0.5,
      blur: 1,
      highlight: 0.92,
      vignette: 0,
      vigOpacity: 0,
      shaderOpacity: 1,
      sweepEase: 1,
      reveal: { duration: 3, pixDuration: 2.6, maskMode: "gradientSweep", maskColorIndex: 3, softness: 0.5 },
    },
  },
}
