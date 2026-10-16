# f3d.yazi

A [Yazi](https://github.com/sxyazi/yazi) previewer for 3D models, rendered with [f3d](https://f3d.app). It handles
glTF/GLB, FBX, OBJ, STL, PLY, USD, 3MF, Collada, STEP/IGES and every other 3D format your f3d build can open,
from meshes and CAD files to point clouds, Gaussian splats and volumes. See [Usage](#usage) for the full list.

- Renders a thumbnail of the model into Yazi's preview cache, so it is only rendered once.
- Orbit the camera around the model with Yazi's preview-scroll keys, <kbd>Shift</kbd>+<kbd>J</kbd> and
  <kbd>Shift</kbd>+<kbd>K</kbd> by default. See [Keybindings](#keybindings).
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

No keymap changes are needed. The plugin uses Yazi's built-in `seek` action, which scrolls the preview. Each
press orbits the camera by one step (`--step`, 45° by default) and wraps around after a full turn:

| Key                              | Action                       |
| -------------------------------- | ---------------------------- |
| <kbd>Shift</kbd>+<kbd>J</kbd>    | Orbit forward (`seek 5`)     |
| <kbd>Shift</kbd>+<kbd>K</kbd>    | Orbit backward (`seek -5`)   |

Plain <kbd>j</kbd>/<kbd>k</kbd> move the file cursor, not the preview. To orbit with other keys, bind them to
`seek` in `~/.config/yazi/keymap.toml`. Only the direction matters, not the number:

```toml
[mgr]
prepend_keymap = [
    { on = "<A-l>", run = "seek 1",  desc = "Orbit the 3D preview forward" },
    { on = "<A-h>", run = "seek -1", desc = "Orbit the 3D preview backward" },
]
```

Those keys then scroll other previews too (text, PDFs, videos), the same as <kbd>J</kbd>/<kbd>K</kbd>.

### Options

Options are passed as arguments in `run`, e.g. `run = "f3d --step=30 --elevation=20 --transparent"`.
Use the same arguments for the preloader and the previewer, otherwise they produce different images.

| Option          | Default  | Description                                                                         |
| --------------- | -------- | ----------------------------------------------------------------------------------- |
| `--azimuth=N`   | `0`      | Starting camera azimuth angle, in degrees.                                          |
| `--elevation=N` | `0`      | Camera elevation angle, in degrees.                                                 |
| `--step=N`      | `45`     | Degrees the camera orbits per scroll. `0` disables orbiting.                        |
| `--transparent` | off      | Render without a background (`f3d --no-background`).                                |
| `--plugins=X`   | `assimp` | f3d plugins to load (`--load-plugins`). Comma separated.                            |
| `--backend=X`   | f3d auto | f3d rendering backend, e.g. `egl` or `osmesa` (f3d 3.x only). See [Headless](#headless). |

Anything else (colors, lighting, HDRI, tone mapping, …) is read from your regular
[f3d configuration file](https://github.com/f3d-app/f3d/blob/master/doc/user/06-CONFIGURATION_FILE.md), so the preview looks the
same as when you open the model in f3d. The output resolution follows Yazi's `max_width`/`max_height`.

### Headless

f3d needs an OpenGL context to render. In a normal desktop session it uses your display. Without one
(for example over SSH), use f3d 3.x with `--backend=egl` (GPU) or `--backend=osmesa` (software), if your
f3d build supports them (`f3d --list-rendering-backends`).

## Notes

- Yazi's `image_alloc` limit is enforced by watching f3d's resident memory rather than with an address-space
  limit, because OpenGL drivers reserve far more address space than they use and fail to start under one.
- f3d 2.x renders an empty scene (and exits successfully) for files it can't parse, so a broken model shows
  up as a blank background instead of an error.

## Clearing the cache

Rendered images are cached by file and camera position. After changing options, clear Yazi's cache with
`yazi --clear-cache`.

## License

MIT
