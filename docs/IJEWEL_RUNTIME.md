# iJewel renderer runtime

The interactive gemstone viewport uses the historical WebGi `0.9.11` runtime and its
`DiamondPlugin`, matching the reference project at https://github.com/Asdii/gemLibrary.

The runtime is consumed as its original package dependency. Its bundled notice states that
commercial use requires a Pixotronics/iJewel3D license. Local development and evaluation do
not remove that requirement for a future commercial release.

The dependency is isolated under `src/rendering/ijewel`. Application geometry, patterns,
placements, cutters, and CSG results remain renderer-independent.
