interface HelpDialogProps {
  readonly onClose: () => void;
  readonly onStartTour: () => void;
}

const workflow = [
  ['Load the gem', 'Load the STL exported from Gem Cut Studio. The default cube is only a practice model.'],
  ['Select a facet', 'Click the flat facet where the pattern will be cut. The pattern is fitted to that facet automatically.'],
  ['Measure the facet', 'Load a reference photo, match the virtual circle, then mark the longest horizontal or vertical span. Scale STL applies the real measurement to the complete project.'],
  ['Draw the pattern', 'Use straight-line shapes in Pattern Designer. Its origin is always (0,0), which maps to the center of the selected facet.'],
  ['Preview and create cuts', 'Adjust position, rotation, scale and depth. Preview cuts is temporary; Create Cuts modifies the working gemstone.'],
  ['Follow Cut Helper', 'After at least one real cut, use Cut Helper to reproduce every cut manually in the indicated order.'],
] as const;

const requirements = [
  ['Measure Facet', 'A facet must be selected.'],
  ['Pattern placement', 'The pattern must contain geometry and a facet must be selected.'],
  ['Create Cuts', 'A non-empty pattern must be placed on the selected facet.'],
  ['Undo Last Cut', 'At least one cut operation must exist.'],
  ['Cut Helper', 'At least one real cut must have been created.'],
  ['Export STL', 'A valid working gemstone must be loaded.'],
] as const;

const controls = [
  ['File', 'Load STL starts from a model. Load/Save Project restores or stores the complete workspace. Export STL writes the currently cut model.'],
  ['Pattern Designer', 'Line and polygon tools create cut geometry. Snap aligns points; Construction geometry helps alignment without becoming a cut.'],
  ['Gem view', 'Drag to orbit, use the mouse wheel to zoom, and use camera buttons for fixed directions. Setup is for placement; Render is for optical inspection.'],
  ['Pattern On Facet', 'Position and rotate the pattern, change its uniform scale, recenter it, or fit it to the selected facet.'],
  ['Cut', 'Choose cutter angle and depth. Preview is reversible; Create Cuts modifies the working mesh; Undo Last Cut rebuilds the previous state.'],
] as const;

export function HelpDialog({ onClose, onStartTour }: HelpDialogProps) {
  return (
    <div className="helpBackdrop" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section className="helpDialog" role="dialog" aria-modal="true" aria-labelledby="help-title">
        <header className="helpHeader">
          <div>
            <h2 id="help-title">Help</h2>
            <p>From a measured facet to a manual V-cut guide.</p>
          </div>
          <button className="toolbarButton" onClick={onClose}>Close</button>
        </header>

        <div className="helpContent">
          <section>
            <h3>Recommended workflow</h3>
            <ol className="helpWorkflow">
              {workflow.map(([title, description]) => (
                <li key={title}>
                  <strong>{title}</strong>
                  <span>{description}</span>
                </li>
              ))}
            </ol>
          </section>

          <section>
            <h3>When tools become available</h3>
            <dl className="helpRequirements">
              {requirements.map(([tool, requirement]) => (
                <div key={tool}>
                  <dt>{tool}</dt>
                  <dd>{requirement}</dd>
                </div>
              ))}
            </dl>
          </section>

          <section>
            <h3>Main controls</h3>
            <dl className="helpRequirements helpControlGuide">
              {controls.map(([tool, description]) => (
                <div key={tool}>
                  <dt>{tool}</dt>
                  <dd>{description}</dd>
                </div>
              ))}
            </dl>
          </section>

          <section className="helpNotes">
            <h3>Important</h3>
            <p>Save Project preserves the STL, cuts, patterns, measurement photo and settings. Export STL exports only the current cut geometry.</p>
            <p>Preview cuts never changes the model. A cut becomes permanent in the working project only after Create Cuts.</p>
          </section>
        </div>

        <footer className="helpActions">
          <button className="toolbarButton active" onClick={onStartTour}>Start guided tour</button>
        </footer>
      </section>
    </div>
  );
}
