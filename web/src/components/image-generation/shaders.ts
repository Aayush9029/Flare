/**
 * WebGL2 port of the libraries.dev `img-fx` image-generation loader.
 *
 * The original evaluates the noise field once per screen pixel, then quantises
 * the result to the mosaic grid, and composites the photo reveal on the CPU
 * with per-cell canvas draws. Both stages are redundant: with `dotMode = 1`
 * the field is constant inside a cell.
 *
 * This port renders the field once per CELL into a grid-sized texture (pass A,
 * a few hundred fragments), then does mosaic masking and the photo reveal in a
 * single full-resolution pass that only samples that texture (pass B). No CPU
 * work runs per frame.
 */

export const VERTEX_SRC = `#version 300 es
void main() {
  vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
  gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}
`

const NOISE = `
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289v2(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289((x * 34.0 + 1.0) * x); }

float snoise(vec2 v) {
  const vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
  vec2 i = floor(v + dot(v, C.yy));
  vec2 x0 = v - i + dot(i, C.xx);
  vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod289v2(i);
  vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
  vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
  m = m * m; m = m * m;
  vec3 x_ = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x_) - 0.5;
  vec3 ox = floor(x_ + 0.5);
  vec3 a0 = x_ - ox;
  m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
  vec3 g;
  g.x = a0.x * x0.x + h.x * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

float fbm(vec2 p, float oct) {
  float val = 0.0, amp = 0.5;
  int n = int(oct);
  for (int i = 0; i < 4; i++) {
    if (i >= n) break;
    val += amp * snoise(p);
    p *= 2.0;
    amp *= 0.5;
  }
  return val;
}
`

/** Pass A: one fragment per mosaic cell. RGB = field colour, A = highlight weight. */
export function cellFragmentSrc(effectIndex: number): string {
  return `#version 300 es
#define EFFECT ${effectIndex}
precision highp float;

uniform vec2 u_grid;
uniform float u_time;
uniform float u_aspect;
uniform vec3 u_color1, u_color2, u_color3, u_color4, u_color5;
uniform float u_alpha1, u_alpha2, u_alpha3, u_alpha4, u_alpha5;
uniform float u_speed, u_intensity, u_scale, u_direction;
uniform float u_distortion, u_complexity, u_shape, u_flicker;
uniform float u_blur;
uniform int u_sweepEase;

out vec4 outColor;

${NOISE}

float nfbm(vec2 p) { return fbm(p, 2.0 + u_complexity * 2.0); }

vec3 palette(float t) {
  t = clamp(t, 0.0, 1.0);
  t = t * t * (3.0 - 2.0 * t);
  const float k = 64.0;
  float w1 = u_alpha1 * exp(-k * t * t);
  float w2 = u_alpha2 * exp(-k * (t - 0.25) * (t - 0.25));
  float w3 = u_alpha3 * exp(-k * (t - 0.5) * (t - 0.5));
  float w4 = u_alpha4 * exp(-k * (t - 0.75) * (t - 0.75));
  float w5 = u_alpha5 * exp(-k * (t - 1.0) * (t - 1.0));
  float total = w1 + w2 + w3 + w4 + w5 + 0.0001;
  return (u_color1 * w1 + u_color2 * w2 + u_color3 * w3 + u_color4 * w4 + u_color5 * w5) / total;
}

vec3 softBlend(float a, float b, float c) {
  a = clamp(a, 0.0, 1.0); a *= a;
  b = clamp(b, 0.0, 1.0); b *= b;
  c = clamp(c, 0.0, 1.0); c *= c;
  float d = clamp(a * 0.7 + c * 0.3, 0.0, 1.0); d *= d;
  float e = clamp(b * 0.5 + c * 0.5, 0.0, 1.0); e *= e;
  a *= u_alpha1; b *= u_alpha2; c *= u_alpha3; d *= u_alpha4; e *= u_alpha5;
  float total = a + b + c + d + e;
  float floorW = max(0.001 - total, 0.0);
  vec3 fallback = (u_color1 + u_color2 + u_color3 + u_color4 + u_color5) * 0.2;
  return (u_color1 * a + u_color2 * b + u_color3 * c + u_color4 * d + u_color5 * e + fallback * floorW) / (total + floorW);
}

vec2 warp(vec2 p, float t) {
  float str = u_distortion * 2.0;
  return vec2(nfbm(p + vec2(t * 0.1, 0.0)), nfbm(p + vec2(0.0, t * 0.12) + 5.0)) * str;
}

float sweepEase(float x) {
  if (u_sweepEase == 1) return x * x * (3.0 - 2.0 * x);
  if (u_sweepEase == 2) { float p = 1.0 - x; return 1.0 - p * p * p; }
  if (u_sweepEase == 3) return x < 0.5 ? 4.0 * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5;
  if (u_sweepEase == 4) return 1.0 - pow(2.0, -10.0 * x) * (1.0 - x);
  return x;
}

vec3 computeEffect(vec2 uv, float t) {
  vec2 p = (uv - 0.5) * u_scale;
  p.x *= u_aspect;
  p += vec2(cos(u_direction), sin(u_direction)) * t * 0.15;
  float dist = u_distortion;
  float cpx = u_complexity;
  float shp = u_shape;
  vec3 col = vec3(0.0);

#if EFFECT == 11
  vec2 q = vec2(nfbm(p * 0.5 + vec2(t * 0.05, 0.0)), nfbm(p * 0.5 + vec2(0.0, t * 0.07)));
  vec2 r = vec2(
    nfbm(p * 0.6 + q * (1.0 + dist * 1.5) + vec2(1.7, 9.2) + t * 0.03),
    nfbm(p * 0.6 + q * (1.0 + dist * 1.5) + vec2(8.3, 2.8) + t * 0.04)
  );
  float f = nfbm(p + r * 1.5);
  float f2 = nfbm(p * 0.7 + r + vec2(3.0, 7.0));
  col = softBlend(
    (f * 0.5 + 0.5) * u_intensity,
    (f2 * 0.5 + 0.5) * u_intensity,
    (nfbm(p * 0.4 - t * 0.02) * 0.5 + 0.5) * u_intensity
  );
#elif EFFECT == 22
  vec2 w = warp(p * 0.7, t * 0.5);
  vec2 w2 = warp(p * 0.4 + w * 0.3, t * 0.3);
  vec2 wp = p + w * (0.4 + dist * 0.6);
  float n1 = snoise(wp * (1.4 + cpx * 1.6) + t * 0.14);
  float n2 = snoise((wp + w2 * dist * 0.4) * (2.0 + cpx * 2.0) + vec2(3.0, 7.0) - t * 0.1);
  float ridge1 = pow(1.0 - abs(n1), 5.0 + shp * 12.0);
  float ridge2 = pow(1.0 - abs(n2), 4.0 + shp * 10.0);
  float base = (n1 + n2) * 0.25 + 0.5;
  col = softBlend(
    (base * 0.6 + ridge1 * 1.2) * u_intensity,
    ((1.0 - base) * 0.6 + ridge2 * 1.0) * u_intensity,
    (ridge1 * 0.8 + ridge2 * 0.6) * u_intensity
  );
#elif EFFECT == 25
  float d = (uv.x + (1.0 - uv.y)) * 0.5;
  float w = 0.9 / max(u_scale, 0.25);
  float cyc = t * 0.08;
  float pA = mix(-w, 1.0 + w, sweepEase(fract(cyc)));
  float pB = mix(-w, 1.0 + w, sweepEase(fract(cyc + 0.5)));
  float band = max(clamp(1.0 - abs(d - pA) / w, 0.0, 1.0), clamp(1.0 - abs(d - pB) / w, 0.0, 1.0));
  float v = band * u_intensity;

  vec2 cell = floor(uv * u_grid);
  float clk = t * 1.6;
  // u_time grows unbounded; wrapping the stepped clock keeps the hash inputs
  // small so mediump GPUs do not lose precision and freeze the flicker.
  float step0 = mod(floor(clk), 1024.0);
  float step1 = mod(step0 + 1.0, 1024.0);
  float fz = smoothstep(0.0, 1.0, fract(clk));
  float cellSeed = dot(cell, vec2(127.1, 311.7));
  float r1 = fract(sin(cellSeed + step0 * 17.23) * 43758.5453);
  float r2 = fract(sin(cellSeed + step1 * 17.23) * 43758.5453);
  v += (mix(r1, r2, fz) - 0.5) * u_flicker * 0.9 * (0.15 + band * 0.85);

  col = palette(clamp(v, 0.0, 1.0));
#endif

  return col;
}

void main() {
  // The framebuffer is exactly u_grid texels, so this uv is the cell centre.
  vec2 uv = gl_FragCoord.xy / u_grid;
  float t = u_time * u_speed;

  vec3 col;
  if (u_blur < 0.01) {
    col = computeEffect(uv, t);
  } else {
    float r = u_blur * 0.02;
    col  = computeEffect(uv, t) * 0.4;
    col += computeEffect(uv + vec2(r, 0.0), t) * 0.15;
    col += computeEffect(uv - vec2(r, 0.0), t) * 0.15;
    col += computeEffect(uv + vec2(0.0, r), t) * 0.15;
    col += computeEffect(uv - vec2(0.0, r), t) * 0.15;
  }

  vec2 cp = (uv - 0.5) * u_scale;
  cp.x *= u_aspect;
  float lw = sin(cp.x * 3.0 + t * 1.5) * 0.5 + 0.5;
  lw *= sin(cp.y * 2.5 - t * 1.1) * 0.5 + 0.5;
  lw += (snoise(cp * 2.0 + t * 0.6) * 0.5 + 0.5) * 0.3;
  float hl = clamp(lw, 0.0, 1.0);

  outColor = vec4(clamp(col, 0.0, 1.0), hl * hl);
}
`
}

/** Pass B: mosaic mask, edge fade, vignette, and the photo reveal composite. */
export const COMPOSITE_FRAGMENT_SRC = `#version 300 es
precision highp float;

uniform sampler2D u_cells;
uniform sampler2D u_image;

uniform vec2 u_resolution;
uniform vec2 u_grid;
uniform float u_dpr;
uniform vec3 u_cardBg;
uniform float u_gap, u_dotOpacity, u_fillOpacity, u_hlScale, u_highlight;
uniform float u_edgeFade, u_fadeStr;
uniform float u_vignette, u_vigOpacity, u_shaderOpacity, u_colorAlpha;

uniform vec4 u_imageRect;      // xy = uv scale, zw = uv offset (cover fit)
uniform float u_imageLod;      // mip level whose texels match one mosaic cell
uniform float u_imageMix;      // 0 = shader only, 1 = reveal fully applied
uniform float u_maskProgress;  // eased silhouette progress
uniform float u_pixProgress;   // eased cell-dissolve progress
uniform float u_maskSoftness;
uniform vec3 u_maskColor;
uniform float u_maskScale;
uniform float u_maskFlicker;
uniform vec3 u_flickerClock;   // x = step, y = next step, z = smoothstepped blend
uniform float u_seed;
uniform int u_maskMode;        // 0 = shader colour proximity, 1 = gradient sweep
uniform int u_hasImage;

out vec4 outColor;

float hash(vec2 cell, float seed) {
  return fract(sin(dot(cell, vec2(127.1, 311.7)) + seed * 17.23) * 43758.5453);
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  vec2 cellId = floor(uv * u_grid);

  vec4 cellTex = texture(u_cells, uv);
  vec3 field = cellTex.rgb;
  float hlFactor = cellTex.a;

  vec2 cssRes = u_resolution / max(u_dpr, 0.0001);
  vec2 cssCoord = uv * cssRes;
  float edgeDistPx = min(min(cssCoord.x, cssRes.x - cssCoord.x), min(cssCoord.y, cssRes.y - cssCoord.y));

  float vigRangePx = 40.0 * (1.0 + u_vignette * 3.0);
  float vig = smoothstep(0.0, 1.0, (edgeDistPx * edgeDistPx) / (vigRangePx * vigRangePx));
  float vigMul = mix(1.0, vig, u_vignette * u_vigOpacity);
  vec3 col = field * vigMul;

  vec2 cellLocal = fract(uv * u_grid);
  float scaleBoost = 1.0 + smoothstep(0.2, 0.8, hlFactor) * u_hlScale * 1.2;

  // Anti-aliased gap: the original steps hard at the cell edge, which shimmers
  // on fractional device pixel ratios. One device pixel of ramp removes it.
  float mask = 1.0;
  float gapW = u_gap * 0.35 / scaleBoost;
  if (gapW > 0.003) {
    vec2 cellPx = u_resolution / u_grid;
    vec2 aa = 1.0 / max(cellPx, vec2(1.0));
    vec2 lo = smoothstep(vec2(gapW) - aa, vec2(gapW) + aa, cellLocal);
    vec2 hi = smoothstep(vec2(gapW) - aa, vec2(gapW) + aa, 1.0 - cellLocal);
    mask = lo.x * lo.y * hi.x * hi.y;
  }

  if (u_highlight > 0.01) {
    float hl = hlFactor * u_highlight;
    col = col * (1.0 + hl * 2.5) + vec3(hl * hl * 0.3);
  }

  if (u_edgeFade > 0.5 && u_fadeStr > 0.005) {
    mask *= mix(1.0, smoothstep(0.0, u_edgeFade, edgeDistPx), u_fadeStr);
  }

  float alpha = u_colorAlpha * mix(u_fillOpacity, u_dotOpacity, mask);
  float bgLum = dot(u_cardBg, vec3(0.299, 0.587, 0.114));
  float colLum = dot(field, vec3(0.299, 0.587, 0.114));
  alpha *= smoothstep(0.0, 0.33, abs(colLum - bgLum));

  vec4 shaderPx = vec4(col, alpha * u_shaderOpacity);

  if (u_hasImage == 0 || u_imageMix <= 0.0) {
    outColor = shaderPx;
    return;
  }

  vec2 imageUv = uv * u_imageRect.xy + u_imageRect.zw;
  vec2 cellCentre = (cellId + 0.5) / u_grid;
  vec2 cellImageUv = cellCentre * u_imageRect.xy + u_imageRect.zw;
  vec3 smoothPixels = texture(u_image, imageUv).rgb;
  vec3 chunkyPixels = textureLod(u_image, cellImageUv, u_imageLod).rgb;

  const float dropBand = 0.07;
  float dropAt = mix(dropBand, 1.0 - dropBand, hash(cellId, u_seed));
  float chunky = clamp(0.5 + (dropAt - u_pixProgress) / (2.0 * dropBand), 0.0, 1.0);
  vec3 imageCol = mix(smoothPixels, chunkyPixels, chunky);

  float a;
  if (u_maskMode == 1) {
    float w = 0.9 / max(u_maskScale, 0.25);
    float pos = -w + u_maskProgress * (1.0 + 2.0 * w);
    float d = (uv.x + (1.0 - uv.y)) * 0.5;
    a = (pos + w - d) / (2.0 * w);
  } else {
    // Matches the reference sampler, which reads the field with the mosaic off:
    // gamma first, then the vignette.
    vec3 sampled = pow(max(field, 0.0), vec3(1.3)) * vigMul;
    vec3 delta = sampled - u_maskColor;
    float val = exp(-8.0 * dot(delta, delta));
    a = (val - (1.0 - u_maskProgress * (1.0 + u_maskSoftness))) / u_maskSoftness;
  }

  if (u_maskFlicker > 0.003) {
    float at = clamp(a, 0.0, 1.0);
    float edge = at * (1.0 - at) * 4.0;
    float rnd = mix(hash(cellId, u_flickerClock.x), hash(cellId, u_flickerClock.y), u_flickerClock.z);
    a += (rnd - 0.5) * u_maskFlicker * 1.6 * edge;
  }

  a = clamp(a, 0.0, 1.0);
  a = a * a * (3.0 - 2.0 * a);

  outColor = mix(shaderPx, vec4(imageCol, 1.0), a * u_imageMix);
}
`
