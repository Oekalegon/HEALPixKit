// swift-tools-version: 6.0
import PackageDescription

// NOTE: Before building, run `scripts/setup_healpix.sh` to download and
// extract healpix_cxx 3.83 into Sources/CHEALPix/.

let package = Package(
    name: "HEALPixKit",
    products: [
        .library(name: "HEALPixKit", targets: ["HEALPixKit"]),
    ],
    targets: [
        // Vendored healpix_cxx C++ sources + thin C bridge
        .target(
            name: "CHEALPix",
            path: "Sources/CHEALPix",
            publicHeadersPath: "include",
            cxxSettings: [
                // healpix_cxx headers live at the source root
                .headerSearchPath("."),
                // Disable OpenMP so no external dependency is required
                .define("HEALPIX_NO_OPENMP"),
            ]
        ),

        // Swift wrapper around the C bridge
        .target(
            name: "HEALPixKit",
            dependencies: ["CHEALPix"]
        ),

        // Tests
        .testTarget(
            name: "HEALPixKitTests",
            dependencies: ["HEALPixKit"]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
