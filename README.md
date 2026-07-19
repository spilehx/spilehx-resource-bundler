# spilehx-resource-bundler

Bundles project resource files into Haxe C++ binaries.

## About

`spilehx-resource-bundler` packages a project resource folder at compile time, embeds the package into the generated binary, and unpacks it at runtime when the local files are missing or out of date.

The library is intended for Haxe C++ projects that need assets such as images, audio, data files, or other runtime resources to travel with the executable.

## Dependencies

- Haxe with C++/hxcpp build support.
- `spilehx-core`, used for logging, archive helpers, folder fingerprinting, and compile-time project helpers.
- The system `tar` command with `.tar.xz` support.

## How It Works

At compile time, `ResourceBundler.bundleResources()`:

- reads the resource folder, `projectResources` by default
- creates a folder fingerprint from file paths, sizes, and modification times
- writes `.temp_bundle_cache/bundleManifest.json`
- writes `.temp_bundle_cache/bundledResources.tar.xz`
- embeds both files into the Haxe build
- adds `.temp_bundle_cache` to `.gitignore`

At runtime, `ResourceBundler.unpackBundledResources()`:

- checks `bundleFiles/bundleManifest.json`
- compares it with the embedded manifest
- extracts the embedded archive when resources are missing or outdated
- leaves existing resources alone when they are already current

## Build Setup

Add the library and bundling macro to your `.hxml` file:

```hxml
-lib spilehx-core
-lib spilehx-resource-bundler
-cp src

--macro spilehx.projectmanagement.resourcebundler.ResourceBundler.bundleResources()

-main Main
-cpp build
```

By default, the bundler looks for:

```text
projectResources/
```

To use a different resource folder, set `assetFolderPath`:

```hxml
-D assetFolderPath=./myResources
```

## Runtime Setup

Call `unpackBundledResources()` when your application starts:

```haxe
class Main {
	static function main():Void {
		spilehx.projectmanagement.resourcebundler.ResourceBundler.unpackBundledResources();
	}
}
```

Resources are unpacked to:

```text
bundleFiles/
```

The call is safe to run more than once. If the files are already up to date, no extraction is performed.

## Public Helpers

`ResourceBundler.getBundledManifest()` returns the embedded manifest data.

`ResourceBundler.getResourceArchive()` returns the embedded archive bytes.

These are useful for validation or custom runtime handling.

## Generated Files

The bundling flow creates local generated output:

```text
.temp_bundle_cache/
bundleFiles/
```

`.temp_bundle_cache/` is compile-time cache output and should not be committed.

`bundleFiles/` is runtime output created by the executable.
