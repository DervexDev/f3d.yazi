# f3d.yazi

A [Yazi](https://github.com/sxyazi/yazi) previewer for FBX models (and any other 3D format your
[f3d](https://f3d.app) build supports), rendered with `f3d`.

- Renders a thumbnail of the model into Yazi's preview cache, so it is only rendered once.
- Scroll the preview (<kbd>J</kbd>/<kbd>K</kbd> by default) to orbit the camera around the model.
- Works as a preloader too, so the image can be rendered before you hover the file.

## Requirements

- Yazi `25.12.29` or newer
- [f3d](https://f3d.app/docs/next/user/INSTALLATION) with the Assimp plugin (needed for FBX).
  Most distro packages and the official release binaries include it. Check with:

  ```sh
  f3d --load-plugins=assimp --list-readers | grep -i fbx   # f3d 3.x
  f3d --load-plugins=assimp --readers-list | grep -i fbx   # f3d 2.x
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
[[plugin.prepend_preloaders]]
url = "*.fbx"
run = "f3d"

[[plugin.prepend_previewers]]
url = "*.fbx"
run = "f3d"
```

Patterns are case-insensitive, so this also matches `.FBX`. To preview other formats f3d can open, add more
patterns, e.g. `url = "*.{fbx,glb,gltf,obj,stl,ply,3ds,dae}"`.

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
[f3d configuration file](https://f3d.app/docs/next/user/CONFIGURATION_FILE), so the preview looks the
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
