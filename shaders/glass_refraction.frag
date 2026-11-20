#version 460 core
#include <flutter/runtime_effect.glsl>

// Engine-owned uniforms: the input may be a full render pass, not the dock.
uniform vec2 uTextureSize;
uniform sampler2D uBackdrop;

// Caller-owned physical-pixel geometry, refreshed before scene composition.
uniform vec2 uOrigin;
uniform vec2 uSurfaceSize;
uniform float uRadius;
uniform float uStrength;
uniform float uEdge;
uniform float uMagnification;
uniform vec2 uViewSize;
// Positive axis scales relative to the smaller physical scale. Appended after
// the existing geometry uniforms so their float indices remain unchanged.
uniform vec2 uAxisScale;
// Interaction progress is applied after the effective displacement bound.
uniform float uOpticsProgress;
// Optional channel separation in the same minimum-axis units as the bevel.
uniform float uDispersion;

out vec4 fragColor;

vec4 sampleTexelCenter(vec2 point) {
  vec2 uv = clamp(point, vec2(0.5), uTextureSize - vec2(0.5)) / uTextureSize;
  // Flutter 3.47 removes the previous GLES input-texture inversion. Retain
  // compatibility with supported earlier engines without double-flipping 3.47.
#if defined(IMPELLER_TARGET_OPENGLES) && !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
  uv.y = 1.0 - uv.y;
#endif
  return texture(uBackdrop, uv);
}

vec4 sampleBackdrop(vec2 point) {
  // ImageFilter.shader owns this sampler and currently uses nearest filtering.
  // Interpolate texel centers explicitly so fractional refraction/magnification
  // does not stair-step glyphs. This is reconstruction, not another blur pass.
  vec2 texel = clamp(point, vec2(0.5), uTextureSize - vec2(0.5)) - vec2(0.5);
  vec2 lower = floor(texel) + vec2(0.5);
  vec2 weight = fract(texel);
  // Identity regions and pass-size/progress fallbacks land on texel centers.
  // Their other three bilinear weights are exactly zero: keep the contributing
  // texel without fetching neighbors. Do not round nearly centered samples;
  // every fractional ray retains the complete reconstruction below.
  if (all(equal(weight, vec2(0.0)))) {
    return sampleTexelCenter(lower);
  }
  vec4 top = mix(
      sampleTexelCenter(lower),
      sampleTexelCenter(lower + vec2(1.0, 0.0)), weight.x);
  vec4 bottom = mix(
      sampleTexelCenter(lower + vec2(0.0, 1.0)),
      sampleTexelCenter(lower + vec2(1.0, 1.0)), weight.x);
  return mix(top, bottom, weight.y);
}

void main() {
  vec2 point = FlutterFragCoord().xy;
  float opticsProgress = clamp(uOpticsProgress, 0.0, 1.0);
  // Public image-filter uniforms do not expose a cropped pass's origin. Root
  // coordinates are valid only for the complete view. Other passes keep blur
  // without risking optics centered on an unrelated part of the backdrop.
  if (opticsProgress == 0.0 ||
      any(greaterThan(abs(uTextureSize - uViewSize), vec2(1.5)))) {
    fragColor = sampleBackdrop(point);
    return;
  }

  vec2 physicalHalfSize = uSurfaceSize * 0.5;
  // Undo nonuniform scaling before evaluating the rounded-rectangle SDF. Its
  // circular corners then map back to the same ellipse as the widget's clip.
  vec2 halfSize = physicalHalfSize / uAxisScale;
  vec2 local = (point - uOrigin - physicalHalfSize) / uAxisScale;
  // The caller normalizes both axis scales to at least one. Outside this
  // half-pixel-padded rectangle the rounded SDF is greater than 0.5, and its
  // physical distance is no smaller. The existing AA path is therefore
  // exactly identity. Reject before evaluating either length or the normal;
  // unexpected sub-unit scales retain the complete path below.
  if (all(greaterThanEqual(uAxisScale, vec2(1.0))) &&
      any(greaterThan(abs(local), halfSize + vec2(0.5)))) {
    fragColor = sampleBackdrop(point);
    return;
  }
  float radius = min(uRadius, min(halfSize.x, halfSize.y));
  vec2 q = abs(local) - halfSize + vec2(radius);
  vec2 outside = max(q, vec2(0.0));
  float outsideLength = length(outside);
  float distanceToEdge = outsideLength + min(max(q.x, q.y), 0.0) - radius;

  // Analytic rounded-rectangle normal: side regions stay straight and corner
  // regions bend smoothly. No finite-difference texture reads are needed.
  vec2 normal;
  if (outsideLength > 0.0001) {
    normal = outside / outsideLength;
  } else {
    normal = q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  }
  normal *= sign(local);

  // Convert the normalized signed distance to physical edge distance for the
  // one-pixel AA transition without moving the exact elliptical boundary.
  float physicalDistanceToEdge =
      distanceToEdge / max(length(normal / uAxisScale), 0.0001);
  // At this existing AA endpoint withinSurface is exactly zero, so the full
  // path samples point and applies no dispersion. Expanded filter inputs can
  // contain many such pixels; skip their inactive optical algebra. Keep the
  // entire AA band and the anisotropic distance calculation unchanged.
  if (physicalDistanceToEdge >= 0.5) {
    fragColor = sampleBackdrop(point);
    return;
  }

  float insideDistance = max(-distanceToEdge, 0.0);
  // Preserve the center-magnification envelope independently of corner radius.
  // Keep the previous one-pixel lower bound where the surface permits it;
  // epsilon only guards subpixel/empty geometry.
  float halfExtent = max(min(halfSize.x, halfSize.y), 0.001);
  float edgeWidth = min(max(uEdge, 1.0), halfExtent);
  // Nearest-edge normals also meet along the interior diagonals of small
  // corners. End their bevel at the radius, before those normals can switch.
  // Square corners have no continuous rounded bevel: bypass it explicitly,
  // without evaluating smoothstep with coincident endpoints.
  float bevelWidth = min(edgeWidth, max(radius, 0.0));
  // Join the unfiltered foreground with identity sampling at the clip boundary.
  // This C1 bell has zero displacement and slope at both bevel endpoints;
  // displacement peaks inside the bevel.
  float edgeWeight = 0.0;
  if (bevelWidth > 0.0) {
    float edgeProgress = smoothstep(0.0, bevelWidth, insideDistance);
    edgeWeight = 4.0 * edgeProgress * (1.0 - edgeProgress);
  }
  // Bound base-ray bevel displacement against the bell's ascending slope when
  // sampling outward. Configured strength remains an upper bound; this is not
  // a global no-fold guarantee with arbitrary magnification or dispersion rays.
  // Scale the bounded strength, preserving a proportional interaction response
  // even when the requested full strength exceeds the effective bevel limit.
  float strength = min(uStrength, bevelWidth * 0.25) * opticsProgress;
  float centerWeight = smoothstep(0.0, edgeWidth * 1.4, insideDistance);
  float withinSurface =
      1.0 - smoothstep(-0.5, 0.5, physicalDistanceToEdge);
  float magnification = mix(1.0, max(uMagnification, 1.0), opticsProgress);
  vec2 magnified = local / magnification;
  vec2 displaced = mix(local, magnified, centerWeight);
  // Outward sampling compresses visible edge features toward the lens interior,
  // opposing center magnification without changing the zero-boundary mapping.
  displaced += normal * strength * edgeWeight;

  // Pixels outside the lens remain unchanged for the composed blur's expanded
  // input region. Foreground tint, labels and glyphs are painted afterward.
  // Add only displacement so the zero-boundary mapping is exactly identity,
  // without reconstructing the original physical point through both scales.
  vec2 samplePoint = point + (displaced - local) * uAxisScale * withinSurface;
  vec4 baseSample = sampleBackdrop(samplePoint);
  float dispersion = min(max(uDispersion, 0.0), bevelWidth * 0.125) *
      opticsProgress * edgeWeight * withinSurface;
  if (dispersion > 0.0) {
    // Split only within the active bevel. Keep the established bilinear/GLES
    // sampling path, and fade both channel offsets to identity at its edges.
    vec2 channelOffset = normal * dispersion * uAxisScale;
    vec4 redSample = sampleBackdrop(samplePoint + channelOffset);
    vec4 blueSample = sampleBackdrop(samplePoint - channelOffset);
    // Inputs are premultiplied. Their maximum alpha bounds every selected RGB
    // channel, including when offsets straddle a transparent foreground edge.
    float alpha = max(baseSample.a, max(redSample.a, blueSample.a));
    vec4 splitSample = vec4(redSample.r, baseSample.g, blueSample.b, alpha);
    // Experimental shared/offset reconstruction attenuates chromatic contrast
    // without extra samples. Mixing complete premultiplied colors also weights
    // coverage; geometry and the existing sample-ray offsets stay unchanged.
    fragColor = mix(baseSample, splitSample, 0.5);
  } else {
    fragColor = baseSample;
  }
}
