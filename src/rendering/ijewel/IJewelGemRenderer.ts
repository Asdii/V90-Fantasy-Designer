import {
  AssetManagerPlugin,
  BloomPlugin,
  DiamondPlugin,
  GBufferPlugin,
  Mesh,
  OrthographicCamera,
  ProgressivePlugin,
  SSAOPlugin,
  SSRPlugin,
  TemporalAAPlugin,
  TonemapPlugin,
  ViewerApp,
  type IModel,
  type ITexture,
  type Texture,
} from 'webgi';
import type { GemMaterial } from '../../materials/GemMaterial';
import type { GemEnvironmentPreset } from '../EnvironmentPreset';
import { createIJewelDiamondSettings } from './IJewelDiamondSettings';
import { createIJewelEnvironment } from './IJewelEnvironment';

export interface IJewelGemRendererOptions {
  readonly projectionMode: 'perspective' | 'orthographic';
  readonly environment: GemEnvironmentPreset;
  readonly background: string;
}

/**
 * Interactive gemstone renderer backed by the WebGi v0.9.19 iJewel DiamondPlugin.
 * The legacy runtime is isolated here; no domain geometry depends on WebGi classes.
 */
export class IJewelGemRenderer {
  readonly viewer: ViewerApp;
  readonly ready: Promise<void>;
  private diamondPlugin?: DiamondPlugin;
  private environmentRequest = 0;
  private gemPreparationRequest = 0;
  private disposed = false;
  private background: string;

  constructor(canvas: HTMLCanvasElement, options: IJewelGemRendererOptions) {
    this.background = options.background;
    this.viewer = new ViewerApp({
      canvas,
      useGBufferDepth: true,
      isAntialiased: false,
      useRgbm: true,
    });
    this.viewer.renderer.displayCanvasScaling = Math.min(window.devicePixelRatio, 1.5);
    canvas.dataset.gemRenderer = 'ijewel-diamond-0.9.19';

    if (options.projectionMode === 'orthographic') {
      const controller = this.viewer.createCamera(new OrthographicCamera(-5, 5, 5, -5, 0.01, 1000));
      this.viewer.scene.activeCamera = controller as typeof this.viewer.scene.activeCamera;
    }

    this.ready = this.initialize(options.environment);
    this.setBackground(options.background);
  }

  get scene() {
    return this.viewer.scene;
  }

  get camera() {
    return this.viewer.scene.activeCamera.cameraObject;
  }

  get controls() {
    return this.viewer.scene.activeCamera.controls;
  }

  async prepareGem(mesh: Mesh, material: GemMaterial, cacheKey: string) {
    const request = ++this.gemPreparationRequest;
    await this.ready;
    if (this.disposed || request !== this.gemPreparationRequest || !mesh.parent) {
      return;
    }
    this.diamondPlugin?.makeDiamondMesh(
      mesh as unknown as IModel<Mesh>,
      // A single edited gem can afford the higher capture resolution. This is
      // especially important for shallow V walls in the plugin's normal map.
      { cacheKey, normalMapRes: 1024, normalMapPrecision: 'high' },
      createIJewelDiamondSettings(material) as import('webgi').DiamondMaterialParameters & { isDiamond?: true },
    );
    console.debug('[WebGiMeshSwap] iJewel material applied');
    this.invalidate();
    console.debug('[WebGiMeshSwap] renderer invalidated');
  }

  setEnvironment(preset: GemEnvironmentPreset) {
    return this.applyEnvironment(preset);
  }

  setBackground(color: string) {
    this.background = color;
    this.viewer.scene.setBackgroundColor(color);
    this.invalidate();
  }

  invalidate() {
    this.viewer.setDirty();
  }

  dispose() {
    if (this.disposed) {
      return;
    }
    this.disposed = true;
    this.environmentRequest += 1;
    this.gemPreparationRequest += 1;
    this.viewer.dispose();
  }

  private async initialize(environment: GemEnvironmentPreset) {
    await addLegacyPlugin(this.viewer, new AssetManagerPlugin());
    this.assertActive();
    await addLegacyPlugin(this.viewer, new GBufferPlugin());
    await addLegacyPlugin(this.viewer, new ProgressivePlugin(32));
    await addLegacyPlugin(this.viewer, new TonemapPlugin(true));
    const ssr = await addLegacyPlugin(this.viewer, new SSRPlugin());
    const ssao = await addLegacyPlugin(this.viewer, new SSAOPlugin());
    const bloom = await addLegacyPlugin(this.viewer, new BloomPlugin());
    await addLegacyPlugin(this.viewer, new TemporalAAPlugin());
    this.diamondPlugin = await addLegacyPlugin(this.viewer, new DiamondPlugin());
    this.assertActive();

    ssr.passes.ssr.passObject.lowQualityFrames = 0;
    ssao.passes.ssao.passObject.material.defines.NUM_SAMPLES = 4;
    bloom.pass!.passObject.bloomIterations = 2;
    this.viewer.renderer.refreshPipeline();
    this.viewer.scene.envMapIntensity = 1.6;
    this.viewer.scene.backgroundIntensity = 1;
    await this.applyEnvironment(environment);
  }

  private async applyEnvironment(preset: GemEnvironmentPreset) {
    const request = ++this.environmentRequest;
    await this.readyIfInitialized();
    if (this.disposed || request !== this.environmentRequest) {
      return;
    }
    const environment = createIJewelEnvironment(preset);
    await this.viewer.setEnvironmentMap(environment.primary);
    if (this.disposed || request !== this.environmentRequest || !this.diamondPlugin) {
      return;
    }

    const manager = this.viewer.getManager();
    const secondary = await manager?.importer?.importSinglePath<ITexture & Texture>(environment.secondary);
    if (this.disposed || request !== this.environmentRequest) {
      secondary?.dispose();
      return;
    }

    this.diamondPlugin.envMap = this.viewer.scene.environment as ITexture;
    this.diamondPlugin.envMap2 = secondary ?? this.diamondPlugin.envMap;
    this.diamondPlugin.envMapRotation = Math.PI / 2;
    this.diamondPlugin.refreshEnvMaps();
    // setEnvironmentMap can replace the scene background asynchronously.
    this.viewer.scene.setBackgroundColor(this.background);
    this.invalidate();
  }

  private async readyIfInitialized() {
    if (this.diamondPlugin) {
      return;
    }
    // initialize() invokes applyEnvironment itself, so awaiting ready here would deadlock.
    await Promise.resolve();
  }

  private assertActive() {
    if (this.disposed) {
      throw new Error('WebGi renderer was disposed during initialization.');
    }
  }
}

// Legacy WebGi ships duplicate invariant ViewerApp declarations that predate TS 5 strict variance.
async function addLegacyPlugin<T>(viewer: ViewerApp, plugin: T): Promise<T> {
  return (viewer.addPlugin as (value: unknown) => Promise<T>)(plugin);
}
