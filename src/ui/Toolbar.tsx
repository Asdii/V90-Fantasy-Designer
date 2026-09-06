import type { BackgroundMode } from '../rendering/background';
import type { CameraViewName } from '../rendering/cameraViews';

interface ToolbarProps {
  readonly background: BackgroundMode;
  readonly facetDebugColors: boolean;
  readonly projectionMode: 'perspective' | 'orthographic';
  readonly showFacetBoundaries: boolean;
  readonly showFacetNormals: boolean;
  readonly showLocalWorkplane: boolean;
  readonly showWireframe: boolean;
  readonly onClearModel: () => void;
  readonly onBackgroundChange: (mode: BackgroundMode) => void;
  readonly onProjectionModeChange: (mode: 'perspective' | 'orthographic') => void;
  readonly onCameraViewRequest: (view: CameraViewName) => void;
  readonly onFacetBoundariesChange: (enabled: boolean) => void;
  readonly onFacetDebugColorsChange: (enabled: boolean) => void;
  readonly onFacetNormalsChange: (enabled: boolean) => void;
  readonly onFitModel: () => void;
  readonly onLocalWorkplaneChange: (enabled: boolean) => void;
  readonly onLoadStl: (file: File) => void;
  readonly onWireframeChange: (enabled: boolean) => void;
}

const cameraViews: { label: string; view: CameraViewName }[] = [
  { label: 'Reset', view: 'reset' },
  { label: 'Top', view: 'top' },
  { label: 'Bottom', view: 'bottom' },
  { label: 'Front', view: 'front' },
  { label: 'Back', view: 'back' },
  { label: 'Left', view: 'left' },
  { label: 'Right', view: 'right' },
  { label: 'Gem Inspection', view: 'inspection' },
];

export function Toolbar({
  background,
  facetDebugColors,
  projectionMode,
  showFacetBoundaries,
  showFacetNormals,
  showLocalWorkplane,
  showWireframe,
  onClearModel,
  onBackgroundChange,
  onProjectionModeChange,
  onCameraViewRequest,
  onFacetBoundariesChange,
  onFacetDebugColorsChange,
  onFacetNormalsChange,
  onFitModel,
  onLocalWorkplaneChange,
  onLoadStl,
  onWireframeChange,
}: ToolbarProps) {
  return (
    <header className="toolbar">
      <div className="toolbarGroup">
        <span className="toolbarLabel">File</span>
        <label className="toolbarButton fileButton">
          Load STL
          <input
            type="file"
            accept=".stl,model/stl,application/sla"
            onChange={(event) => {
              const file = event.target.files?.[0];
              if (file) {
                onLoadStl(file);
              }
              event.target.value = '';
            }}
          />
        </label>
        <button className="toolbarButton" onClick={onClearModel}>
          Clear model
        </button>
      </div>
      <div className="toolbarGroup">
        <span className="toolbarLabel">Camera</span>
        <button className="toolbarButton" onClick={onFitModel}>
          Fit to model
        </button>
        {cameraViews.map((item) => (
          <button key={item.view} className="toolbarButton" onClick={() => onCameraViewRequest(item.view)}>
            {item.label}
          </button>
        ))}
      </div>
      <div className="toolbarGroup">
        <span className="toolbarLabel">Projection</span>
        <button
          className={projectionMode === 'perspective' ? 'toolbarButton active' : 'toolbarButton'}
          onClick={() => onProjectionModeChange('perspective')}
        >
          Perspective
        </button>
        <button
          className={projectionMode === 'orthographic' ? 'toolbarButton active' : 'toolbarButton'}
          onClick={() => onProjectionModeChange('orthographic')}
        >
          Orthographic
        </button>
      </div>
      <div className="toolbarGroup">
        <span className="toolbarLabel">Background</span>
        <select
          className="toolbarSelect"
          value={background}
          onChange={(event) => onBackgroundChange(event.target.value as BackgroundMode)}
        >
          <option value="black">Black</option>
          <option value="darkGray">Dark gray</option>
          <option value="lightGray">Light gray</option>
          <option value="white">White</option>
          <option value="neutral">Neutral</option>
        </select>
      </div>
      <label className="wireframeToggle">
        <input
          type="checkbox"
          checked={showWireframe}
          onChange={(event) => onWireframeChange(event.target.checked)}
        />
        Wireframe
      </label>
      <label className="wireframeToggle">
        <input
          type="checkbox"
          checked={showFacetBoundaries}
          onChange={(event) => onFacetBoundariesChange(event.target.checked)}
        />
        Facet boundaries
      </label>
      <label className="wireframeToggle">
        <input
          type="checkbox"
          checked={facetDebugColors}
          onChange={(event) => onFacetDebugColorsChange(event.target.checked)}
        />
        Facet colors
      </label>
      <label className="wireframeToggle">
        <input
          type="checkbox"
          checked={showFacetNormals}
          onChange={(event) => onFacetNormalsChange(event.target.checked)}
        />
        Facet normals
      </label>
      <label className="wireframeToggle">
        <input
          type="checkbox"
          checked={showLocalWorkplane}
          onChange={(event) => onLocalWorkplaneChange(event.target.checked)}
        />
        Local workplane
      </label>
    </header>
  );
}
