# f3d.yazi

A [Yazi](https://github.com/sxyazi/yazi) previewer for 3D models, rendered with [f3d](https://f3d.app). It handles
glTF/GLB, FBX, OBJ, STL, PLY, USD, 3MF, Collada, STEP/IGES and every other 3D format your f3d build can open,
from meshes and CAD files to point clouds, Gaussian splats and volumes. See [Usage](#usage) for the full list.

- Renders a thumbnail of the model into Yazi's preview cache, so it is only rendered once.
- Orbit the camera around the model with Yazi's preview-scroll keys (<kbd>J</kbd>/<kbd>K</kbd> by default),
  and zoom in and out. See [Keybindings](#keybindings).
- Shows model statistics (vertices, triangles, meshes, materials, size, …) under the preview and in Yazi's file
  info popup (<kbd>Tab</kbd>).
- Works as a preloader too, so the image can be rendered before you hover the file.

## Requirements

- Yazi `25.12.29` or newer
- [f3d](https://github.com/f3d-app/f3d), with the plugins for the formats you want to preview. Formats like FBX,
  Collada and 3MF need the `assimp` plugin, and STEP/IGES need `occt`. Most distro packages and the official
  release binaries include both. List the formats your build can open with:

  ```sh
  f3d --list-readers   # f3d 3.x
  f3d --load-plugins=assimp,occt --readers-list   # f3d 2.x
  ```

- An image-capable terminal, as for any other Yazi image preview.
- Optional: the [Assimp](https://github.com/assimp/assimp) command-line tool (`assimp`), for model statistics. It's
  packaged as `assimp-utils` on Debian/Ubuntu and `assimp` on Arch, Homebrew and most other distros. Statistics are
  available for the mesh formats Assimp reads (FBX, glTF, OBJ, STL, PLY, Collada, 3DS, 3MF, …), not for CAD files,
  point clouds, splats or volumes.

## Installation

```sh
ya pkg add DervexDev/f3d.yazi
```

Or clone it manually:

```sh
git clone https://github.com/DervexDev/f3d.yazi ~/.config/yazi/plugins/f3d.yazi
```

## Usage

Add to `~/.config/yazi/yazi.toml`:

```toml
[plugin]
prepend_preloaders = [
    # Meshes and scenes
    { url = "*.{3ds,3mf,abc,amf,dae,drc,dxf,fbx,glb,gltf,mdl,obj,off,ply,stl,usd,usda,usdc,usdz,vrml,wrl,x}", run = "f3d" },
    # CAD and BIM
    { url = "*.{brep,fcstd,ifc,iges,igs,p21,step,stp,stpnc,xbf}", run = "f3d" },
    # Point clouds and GIS
    { url = "*.{bpf,csd,gml,las,laz,pcd,pts,ptx,qi,sbet,slpk}", run = "f3d" },
    # Gaussian splats
    { url = "*.{splat,spz}", run = "f3d" },
    # Scientific and volumetric data
    { url = "*.{cdf,dcm,ex2,exo,mha,mhd,nc,ncdf,nhdr,nrrd,vdb,vti,vtk,vtkhdf,vtm,vtp,vtr,vts,vtu}", run = "f3d" },
]

prepend_previewers = [
    # Meshes and scenes
    { url = "*.{3ds,3mf,abc,amf,dae,drc,dxf,fbx,glb,gltf,mdl,obj,off,ply,stl,usd,usda,usdc,usdz,vrml,wrl,x}", run = "f3d" },
    # CAD and BIM
    { url = "*.{brep,fcstd,ifc,iges,igs,p21,step,stp,stpnc,xbf}", run = "f3d" },
    # Point clouds and GIS
    { url = "*.{bpf,csd,gml,las,laz,pcd,pts,ptx,qi,sbet,slpk}", run = "f3d" },
    # Gaussian splats
    { url = "*.{splat,spz}", run = "f3d" },
    # Scientific and volumetric data
    { url = "*.{cdf,dcm,ex2,exo,mha,mhd,nc,ncdf,nhdr,nrrd,vdb,vti,vtk,vtkhdf,vtm,vtp,vtr,vts,vtu}", run = "f3d" },
]

prepend_spotters = [
    # Meshes and scenes
    { url = "*.{3ds,3mf,abc,amf,dae,drc,dxf,fbx,glb,gltf,mdl,obj,off,ply,stl,usd,usda,usdc,usdz,vrml,wrl,x}", run = "f3d" },
    # CAD and BIM
    { url = "*.{brep,fcstd,ifc,iges,igs,p21,step,stp,stpnc,xbf}", run = "f3d" },
    # Point clouds and GIS
    { url = "*.{bpf,csd,gml,las,laz,pcd,pts,ptx,qi,sbet,slpk}", run = "f3d" },
    # Gaussian splats
    { url = "*.{splat,spz}", run = "f3d" },
    # Scientific and volumetric data
    { url = "*.{cdf,dcm,ex2,exo,mha,mhd,nc,ncdf,nhdr,nrrd,vdb,vti,vtk,vtkhdf,vtm,vtp,vtr,vts,vtu}", run = "f3d" },
]
```

This covers every 3D format [f3d supports](https://github.com/f3d-app/f3d/blob/master/doc/user/02-SUPPORTED_FORMATS.md), except:

- 2D images (`png`, `jpg`, `exr`, `hdr`, `tif`, …), which Yazi already previews.
- Extensions too generic to claim for every file that has them: ExodusII's `e`/`g`, TerraScan's `bin` and STEP's `210`.
  Add them yourself if you need them.

Patterns are case-insensitive, so `*.stl` also matches `.STL`. Each format needs the matching f3d plugin, and the
selection depends on your f3d build and version. Check what yours supports with `f3d --list-readers`
(`--readers-list` on f3d 2.x), and trim the list to those formats so unsupported files fall back to Yazi's
default previewers.

f3d 3.x loads all of its plugins automatically. On f3d 2.x, only `assimp` is loaded unless you list more, e.g.
`run = "f3d --plugins=assimp,occt,alembic"`.

### Keybindings

#### Orbit

Orbiting uses Yazi's built-in `seek` action, so it works without any keymap changes. Each press orbits the camera
around the model's vertical axis by one step (`--step`, 45° by default) and wraps around after a full turn:

| Key          | Action                     |
| ------------ | -------------------------- |
| <kbd>J</kbd> | Orbit forward (`seek 5`)   |
| <kbd>K</kbd> | Orbit backward (`seek -5`) |

To orbit with other keys, bind them to `seek` in `~/.config/yazi/keymap.toml`. Only the direction matters, not the
number. These keys scroll other previews too (text, PDFs, videos), the same as <kbd>J</kbd>/<kbd>K</kbd>:

```toml
[mgr]
prepend_keymap = [
    { on = "<A-l>", run = "seek 1",  desc = "Orbit the 3D preview forward" },
    { on = "<A-h>", run = "seek -1", desc = "Orbit the 3D preview backward" },
]
```

#### Zoom

Zooming needs keybindings, and f3d 3.x. Add to `~/.config/yazi/keymap.toml`:

```toml
[mgr]
prepend_keymap = [
    { on = "+", run = "plugin f3d 1",  desc = "Zoom in hovered file" },
    { on = "-", run = "plugin f3d -1", desc = "Zoom out hovered file" },
]
```

On any file that isn't previewed by this plugin, the keys run [zoom.yazi](https://github.com/yazi-rs/plugins/tree/main/zoom.yazi)
instead (`plugin zoom 1` / `plugin zoom -1`), so the same keys zoom both images and 3D models. If you use zoom.yazi,
replace its keybindings with these.

### Options

Options are passed as arguments in `run`, e.g. `run = "f3d --step=30 --elevation=30"`.
Use the same arguments for the preloader and the previewer, otherwise they produce different images. The spotter
doesn't take any options.

| Option          | Default  | Description                                                                         |
| --------------- | -------- | ----------------------------------------------------------------------------------- |
| `--azimuth=N`   | `0`      | Starting camera angle around the up axis, in degrees. `0` is f3d's default view.    |
| `--elevation=N` | `19.47`  | Camera angle above the horizon, in degrees. The default matches f3d's default view. |
| `--up=X`        | `+Y`     | World up axis: `+Y`, `-Y`, `+Z`, … (`f3d --up`). The camera orbits around it.       |
| `--step=N`      | `45`     | Degrees the camera orbits per scroll. `0` disables orbiting.                        |
| `--stats`       | on       | Show model statistics under the preview. `--stats=false` disables it.               |
| `--config=X`    | bundled  | f3d config file to use: a path, or a name looked up in f3d's config directories. See [Appearance](#appearance). |
| `--plugins=X`   | `assimp` | f3d plugins to load (`--load-plugins`). Comma separated.                            |
| `--backend=X`   | f3d auto | f3d rendering backend, e.g. `egl` or `osmesa` (f3d 3.x only). See [Headless](#headless). |

The output resolution follows Yazi's `max_width`/`max_height`.

### Appearance

All visual settings live in the plugin's own f3d config, [`f3d.json`](f3d.json), which previews use instead of your
regular f3d config. That keeps overlays meant for the f3d window (file name, progress bars, …) out of the preview.
By default it renders on a transparent background with ambient HDRI lighting, tone mapping and anti-aliasing. The
axes widget (`axis`), ground grid (`grid`) and skeleton display (`armature`) are listed too, turned off, so they're
easy to switch on.

To customize it, copy `f3d.json` to f3d's config directory (`~/.config/f3d/` on Linux,
`~/Library/Application Support/f3d/` on macOS, `%APPDATA%\f3d\` on Windows) under a new name, e.g. `yazi.json`, edit
it with any [f3d option](https://github.com/f3d-app/f3d/blob/master/doc/user/03-OPTIONS.md), and point the plugin at
it with `run = "f3d --config=yazi"`. The camera position is always set by the plugin, so camera options in the file
are ignored.

> [!NOTE]
> Rendered images are cached by file and camera position, so changes to the config or to the plugin options don't
> apply to models you've already previewed. Clear Yazi's cache with `yazi --clear-cache` after changing them.

The config file uses the f3d 3.x format, so f3d 2.x ignores it and renders with its defaults.

### Headless

f3d needs an OpenGL context to render. In a normal desktop session it uses your display. Without one
(for example over SSH), use f3d 3.x with `--backend=egl` (GPU) or `--backend=osmesa` (software), if your
f3d build supports them (`f3d --list-rendering-backends`).

## Notes

- Yazi's `image_alloc` limit is enforced by watching f3d's resident memory rather than with an address-space
  limit, because OpenGL drivers reserve far more address space than they use and fail to start under one.
- f3d 2.x renders an empty scene (and exits successfully) for files it can't parse, so a broken model shows
  up as a blank background instead of an error.

## License

MIT
