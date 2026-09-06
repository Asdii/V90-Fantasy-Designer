import { useState } from 'react';
import type { GemProject } from '../project/GemProject';
import { createFacetLocalGeometry } from '../geometry/FacetLocalGeometry';

interface ModelInfoPanelProps {
  readonly project: GemProject;
  readonly importError?: string;
  readonly selectedFacetId?: number;
}

export function ModelInfoPanel({ project, importError, selectedFacetId }: ModelInfoPanelProps) {
  const [debugGeometry, setDebugGeometry] = useState(false);
  const geometry = project.geometry;
  const selectedFacet =
    selectedFacetId !== undefined ? geometry?.facets.find((facet) => facet.id === selectedFacetId) : undefined;
  const selectedLocalGeometry = geometry && selectedFacet ? createFacetLocalGeometry(geometry, selectedFacet) : undefined;

  return (
    <aside className="modelInfoPanel">
      <h2>Gem</h2>
      {importError ? <p className="errorText">{importError}</p> : null}
      <dl>
        <dt>File</dt>
        <dd>{project.source?.filename ?? 'Placeholder geometry'}</dd>
        <dt>Units</dt>
        <dd>mm (1 STL unit = 1 mm)</dd>
        <dt>Facets</dt>
        <dd>{geometry?.facets.length ?? 0}</dd>
      </dl>
      {geometry ? (
        <>
          <h3>Dimensions</h3>
          <dl>
            <dt>X</dt>
            <dd>{formatMm(geometry.boundingBox.size.x)}</dd>
            <dt>Y</dt>
            <dd>{formatMm(geometry.boundingBox.size.y)}</dd>
            <dt>Z</dt>
            <dd>{formatMm(geometry.boundingBox.size.z)}</dd>
          </dl>
          <label className="wireframeToggle">
            <input
              type="checkbox"
              checked={debugGeometry}
              onChange={(event) => setDebugGeometry(event.target.checked)}
            />
            Debug geometry
          </label>
          {debugGeometry ? (
            <>
              <h3>Mesh debug</h3>
              <dl>
                <dt>Vertices</dt>
                <dd>{geometry.vertices.length}</dd>
                <dt>Triangles</dt>
                <dd>{geometry.triangles.length}</dd>
                <dt>Edges</dt>
                <dd>{geometry.edges.length}</dd>
                <dt>Largest facet</dt>
                <dd>{formatMm2(Math.max(...geometry.facets.map((facet) => facet.area)))}</dd>
                <dt>Smallest facet</dt>
                <dd>{formatMm2(Math.min(...geometry.facets.map((facet) => facet.area)))}</dd>
              </dl>
              <h3>Bounding box center</h3>
              <dl>
                <dt>X</dt>
                <dd>{formatMm(geometry.boundingBox.center.x)}</dd>
                <dt>Y</dt>
                <dd>{formatMm(geometry.boundingBox.center.y)}</dd>
                <dt>Z</dt>
                <dd>{formatMm(geometry.boundingBox.center.z)}</dd>
              </dl>
              <h3>Geometry warnings</h3>
              {geometry.warnings.length > 0 ? (
                <ul className="warningList">
                  {geometry.warnings.map((warning) => (
                    <li key={warning.code}>{warning.message}</li>
                  ))}
                </ul>
              ) : (
                <p>No warnings</p>
              )}
            </>
          ) : null}
          <h3>Selected facet</h3>
          {selectedFacet ? (
            <>
              <dl>
                <dt>ID</dt>
                <dd>{selectedFacet.id}</dd>
                <dt>Boundary vertices</dt>
                <dd>{selectedFacet.boundaryVertexIndices.length}</dd>
              </dl>
              {debugGeometry ? (
                <>
                  <h3>Facet debug</h3>
                  <dl>
                    <dt>Triangles</dt>
                    <dd>{selectedFacet.triangleIndices.length}</dd>
                    <dt>Area</dt>
                    <dd>{formatMm2(selectedFacet.area)}</dd>
                    <dt>Centroid X</dt>
                    <dd>{formatMm(selectedFacet.centroid.x)}</dd>
                    <dt>Centroid Y</dt>
                    <dd>{formatMm(selectedFacet.centroid.y)}</dd>
                    <dt>Centroid Z</dt>
                    <dd>{formatMm(selectedFacet.centroid.z)}</dd>
                    <dt>Normal X</dt>
                    <dd>{formatNormal(selectedFacet.normal.x)}</dd>
                    <dt>Normal Y</dt>
                    <dd>{formatNormal(selectedFacet.normal.y)}</dd>
                    <dt>Normal Z</dt>
                    <dd>{formatNormal(selectedFacet.normal.z)}</dd>
                    <dt>Plane d</dt>
                    <dd>{selectedFacet.plane.constant.toFixed(6)}</dd>
                  </dl>
                </>
              ) : null}
              {debugGeometry && selectedLocalGeometry ? (
                <>
                  <h3>Local frame</h3>
                  <dl>
                    <dt>Origin X</dt>
                    <dd>{formatMm(selectedLocalGeometry.frame.origin.x)}</dd>
                    <dt>Origin Y</dt>
                    <dd>{formatMm(selectedLocalGeometry.frame.origin.y)}</dd>
                    <dt>Origin Z</dt>
                    <dd>{formatMm(selectedLocalGeometry.frame.origin.z)}</dd>
                  </dl>
                  <h3>U axis</h3>
                  <dl>
                    <dt>X</dt>
                    <dd>{formatNormal(selectedLocalGeometry.frame.uAxis.x)}</dd>
                    <dt>Y</dt>
                    <dd>{formatNormal(selectedLocalGeometry.frame.uAxis.y)}</dd>
                    <dt>Z</dt>
                    <dd>{formatNormal(selectedLocalGeometry.frame.uAxis.z)}</dd>
                  </dl>
                  <h3>V axis</h3>
                  <dl>
                    <dt>X</dt>
                    <dd>{formatNormal(selectedLocalGeometry.frame.vAxis.x)}</dd>
                    <dt>Y</dt>
                    <dd>{formatNormal(selectedLocalGeometry.frame.vAxis.y)}</dd>
                    <dt>Z</dt>
                    <dd>{formatNormal(selectedLocalGeometry.frame.vAxis.z)}</dd>
                  </dl>
                  <h3>N axis</h3>
                  <dl>
                    <dt>X</dt>
                    <dd>{formatNormal(selectedLocalGeometry.frame.normal.x)}</dd>
                    <dt>Y</dt>
                    <dd>{formatNormal(selectedLocalGeometry.frame.normal.y)}</dd>
                    <dt>Z</dt>
                    <dd>{formatNormal(selectedLocalGeometry.frame.normal.z)}</dd>
                  </dl>
                  <h3>Local bounds</h3>
                  <dl>
                    <dt>U</dt>
                    <dd>
                      {selectedLocalGeometry.bounds.minU.toFixed(3)} .. {selectedLocalGeometry.bounds.maxU.toFixed(3)} mm
                    </dd>
                    <dt>V</dt>
                    <dd>
                      {selectedLocalGeometry.bounds.minV.toFixed(3)} .. {selectedLocalGeometry.bounds.maxV.toFixed(3)} mm
                    </dd>
                    <dt>Size</dt>
                    <dd>
                      {selectedLocalGeometry.bounds.width.toFixed(3)} x {selectedLocalGeometry.bounds.height.toFixed(3)} mm
                    </dd>
                  </dl>
                </>
              ) : null}
            </>
          ) : (
            <p>No selected facet</p>
          )}
        </>
      ) : null}
    </aside>
  );
}

function formatMm(value: number) {
  return `${value.toFixed(3)} mm`;
}

function formatMm2(value: number) {
  if (!Number.isFinite(value)) {
    return '0.000 mm^2';
  }

  return `${value.toFixed(3)} mm^2`;
}

function formatNormal(value: number) {
  return value.toFixed(6);
}
