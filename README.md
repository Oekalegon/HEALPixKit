# HEALPixKit

A Swift 6 package that bridges [HEALPix](https://healpix.sourceforge.io) — the standard sphere pixelization used in CMB analysis and astronomy. HEALPix divides the sphere into equal-area pixels, making it easy to store and query data on the sky.

The healpix_cxx 3.83 C++ sources (GPL-2+) are vendored directly, so no system libraries need to be installed.

---

## Requirements

- Swift 6+
- macOS 14+ or iOS 17+

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/HEALPixKit", from: "1.0.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: ["HEALPixKit"]),
]
```

---

## Core concepts

| Concept | Description |
|---|---|
| `Resolution` | Wraps the `nside` parameter (power of 2). Pixel count = `12 × nside²`. |
| `PixelScheme` | `.ring` (iso-latitude rings, good for power spectra) or `.nested` (quadtree, good for neighbours). |
| `HEALPix` | A grid combining resolution + scheme. All conversions live here. |
| `AngularCoordinate` | A point on the sphere as colatitude `theta` ∈ [0, π] and longitude `phi` ∈ [0, 2π). |

---

## Usage

### Create a grid

```swift
import HEALPixKit

let grid = HEALPix(resolution: .nside64, scheme: .ring)
print(grid.npix)  // 49152
```

Or pick a resolution by nside value or HEALPix order:

```swift
let res = Resolution(nside: 512)   // nside directly
let res = Resolution(order: 9)     // 2^9 = 512
```

---

### Angular coordinate → pixel

```swift
let coord = AngularCoordinate(theta: 0.3, phi: 1.2)  // colatitude, longitude (radians)
let ipix  = grid.pixel(at: coord)                     // Int64
```

From equatorial RA / Dec (both in radians):

```swift
let coord = AngularCoordinate(rightAscension: ra, declination: dec)
let ipix  = grid.pixel(at: coord)
```

---

### Pixel → angular coordinate

Returns the centre of the pixel:

```swift
let centre = grid.angularCoordinate(of: ipix)
print(centre.theta)         // colatitude in radians
print(centre.declination)   // π/2 − theta
print(centre.phi)           // longitude in radians
print(centre.rightAscension)
```

---

### Unit vector ↔ pixel

```swift
// Direction → pixel
let ipix = grid.pixel(for: (x: 0.0, y: 1.0, z: 0.0))

// Pixel → direction
let vec = grid.vector(of: ipix)  // (x: Double, y: Double, z: Double)
```

---

### Scheme conversion

Convert a pixel index between RING and NESTED orderings:

```swift
let ringGrid   = HEALPix(resolution: .nside64, scheme: .ring)
let nestedGrid = HEALPix(resolution: .nside64, scheme: .nested)

let ipixRing   = ringGrid.pixel(at: coord)
let ipixNested = ringGrid.convert(pixel: ipixRing, to: .nested)
let backToRing = nestedGrid.convert(pixel: ipixNested, to: .ring)
// backToRing == ipixRing
```

---

### Resolution table

| Static constant | nside | npix |
|---|---|---|
| `.nside1` | 1 | 12 |
| `.nside2` | 2 | 48 |
| `.nside4` | 4 | 192 |
| `.nside8` | 8 | 768 |
| `.nside16` | 16 | 3 072 |
| `.nside32` | 32 | 12 288 |
| `.nside64` | 64 | 49 152 |
| `.nside128` | 128 | 196 608 |
| `.nside256` | 256 | 786 432 |
| `.nside512` | 512 | 3 145 728 |
| `.nside1024` | 1024 | ~12.6 M |
| `.nside2048` | 2048 | ~50.3 M |

---

### Cone query — find pixels near a point

```swift
let grid   = HEALPix(resolution: .nside64, scheme: .ring)
let centre = AngularCoordinate(rightAscension: ra, declination: dec)

// Exact: returns pixels whose *centres* lie within 0.1 rad (~5.7°)
let pixels = grid.pixels(inConeAround: centre, radius: 0.1)

// Inclusive: also catches pixels that overlap the boundary
let pixels = grid.pixels(inConeAround: centre, radius: 0.1, inclusive: true)
```

`maxPixelRadius` gives the half-size of the largest pixel at this resolution, useful as a buffer:

```swift
// Guarantee every overlapping pixel is included
let safeRadius = searchRadius + grid.maxPixelRadius
let pixels = grid.pixels(inConeAround: centre, radius: safeRadius)
```

---

### Star catalog example

```swift
import HEALPixKit

struct Star {
    let name: String
    let rightAscension: Double  // radians
    let declination: Double     // radians
}

let grid = HEALPix(resolution: .nside64, scheme: .nested)  // nested = fast neighbours

// Index the catalog
let catalog: [Int64: [Star]] = Dictionary(grouping: stars) { star in
    grid.pixel(at: AngularCoordinate(rightAscension: star.rightAscension,
                                     declination: star.declination))
}

// Query: all stars within 0.1 rad of a target
let target  = AngularCoordinate(rightAscension: 1.2, declination: 0.5)
let pixels  = grid.pixels(inConeAround: target, radius: 0.1)

let candidates = pixels.flatMap { catalog[$0] ?? [] }

// Optionally apply an exact angular-distance filter on candidates
```

**Why `.nested` for catalogs?** The nested scheme groups spatially nearby pixels together, so cone-query results are a compact range of indices rather than scattered ones — better for cache locality when walking the dictionary.

---

## License

Both HEALPixKit's Swift wrapper and the vendored healpix_cxx C++ sources (`Sources/CHEALPix/`) are licensed under the GNU General Public License v2 or later (GPL-2+). See the [HEALPix project](https://healpix.sourceforge.io) for details.
