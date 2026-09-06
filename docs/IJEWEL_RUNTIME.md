# iJewel renderer runtime

The interactive gemstone viewport uses the historical WebGi `0.9.19` runtime and its
`DiamondPlugin`, matching the reference project at https://github.com/Asdii/gemLibrary.

Version `0.9.17` was the first legacy release whose changelog explicitly included fixes for
concave geometry in `DiamondPlugin`; `0.9.19` adds further topology and incorrect-input edge
case fixes. Normal capture uses 1024px/high precision so shallow V-cut walls retain
substantially more directional detail than the former 512px setup.

The material uses the plugin maximum of six internal ray bounces. Increasing this value is
not a remedy for concave artifacts: the realtime implementation uses precomputed directional
normal data and remains an approximation rather than triangle-accurate path tracing.

The runtime is consumed as its original package dependency. Its bundled notice states that
commercial use requires a Pixotronics/iJewel3D license. Local development and evaluation do
not remove that requirement for a future commercial release.

The dependency is isolated under `src/rendering/ijewel`. Application geometry, patterns,
placements, cutters, and CSG results remain renderer-independent.
