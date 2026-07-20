package spilehx.projectmanagement.resourcebundler;

import haxe.Json;
#if macro
import spilehx.core.macrotools.MacroTools;
import spilehx.core.projectmanagement.FolderFingerprint;
import spilehx.core.logging.Log;
#end
import haxe.format.JsonPrinter;
import Date;
import spilehx.core.projectmanagement.Archive;
import sys.FileSystem;
import sys.io.File;
import sys.FileStat;
import spilehx.core.logging.GlobalLogger;
import spilehx.core.logging.GlobalLogger.*;

class ResourceBundler {
	private static var ENV_KEY_bundledFolderPath:String = "outputBundleFolderPath";
	private static var ENV_DEFAULT_bundledFolderPath:String = "bundleFiles";

	private static var ENV_KEY_assetFolderPath:String = "assetFolderPath";
	private static var ENV_DEFAULT_assetFolderPath:String = "projectResources";
	private static var tempOutputFolderPath:String = ".temp_bundle_cache";

	private static final MANIFEST_FILE_NAME:String = "bundleManifest.json";
	private static final ARCHIVE_FILE_NAME:String = "bundledResources.tar.xz";
	private static final BUNDLED_FILES:Array<String> = [ARCHIVE_FILE_NAME, MANIFEST_FILE_NAME];

	#if macro
	public static macro function bundleResources():haxe.macro.Expr {
		Log.compileTimeLog("SpileHX: Packaging runtime resources...");
		var assetFolderPath = MacroTools.getEnvVar(ENV_KEY_assetFolderPath, ENV_DEFAULT_assetFolderPath);
			var outputFolderPath = tempOutputFolderPath;
			var manifestFilePath = outputFolderPath + "/" + MANIFEST_FILE_NAME;

			// ensure basic setup
			MacroTools.ensureProjectFolder(assetFolderPath);
			MacroTools.ensureProjectFolder(outputFolderPath);

			var projectPath = MacroTools.validateProjectPath(".");
			spilehx.core.projectsetup.ProjectConfigEntry.createGitIgnoreEntry(outputFolderPath, projectPath);

		// Proceed with packaging
		var folderFingerprint = FolderFingerprint.fingerprint(assetFolderPath);
		var currentFingerprint = getCurrentBundleFingerPrint(manifestFilePath);

		if (currentFingerprint == folderFingerprint) {
			Log.compileTimeLog("No changes detected. Skipping packaging.");

			// no new but bundle anyway to ensure the resources are bundled in the current build
			addBundledResource(outputFolderPath);

			return macro {};
		}

		Log.compileTimeLog("Changes detected!! Proceeding with packaging.");

		var currentDate = Date.now();
		var epochTime = Std.int(currentDate.getTime() / 1000);
		var assetFiles = MacroTools.getFilesRecursively(assetFolderPath);

		var jsonObject = {
			timestamp: epochTime,
			files: assetFiles,
			fingerprint: folderFingerprint
		};

		writeBundleManifestFile(jsonObject, manifestFilePath);

		Archive.createArchive(assetFolderPath, outputFolderPath, ARCHIVE_FILE_NAME, function() {
			Log.compileTimeLog("Archive created successfully.");
			addBundledResource(outputFolderPath);
		});

		return macro {};
	}

	private static function writeBundleManifestFile(jsonObject, manifestFilePath:String) {
		var jsonString = JsonPrinter.print(jsonObject);

		try {
			File.saveContent(manifestFilePath, jsonString);
		} catch (e:Dynamic) {
			haxe.macro.Context.error("Failed to write timestamp JSON to file: " + Std.string(e), haxe.macro.Context.currentPos());
		}
	}

	private static function getCurrentBundleFingerPrint(manifestFilePath:String):String {
		if (!FileSystem.exists(manifestFilePath)) {
			return "";
		}

		var manifestContent = File.getContent(manifestFilePath);
		var manifestData = haxe.Json.parse(manifestContent);
		return manifestData.fingerprint;
	}

	private static function addBundledResource(outputFolderPath:String):Void {
		Log.compileTimeLog("Adding bundled resources to the build...");
		for (name in BUNDLED_FILES) {
			var filePath:String = outputFolderPath + "/" + name;

			if (!FileSystem.exists(filePath)) {
				haxe.macro.Context.fatalError('Resource file not found: $filePath', haxe.macro.Context.currentPos());
			}

			haxe.macro.Context.addResource(name, File.getBytes(filePath));
		}
	}
	#end

	// runtime extraction of the bundled resources
	public static function unpackBundledResources():Void {
		var targetFolderPath:String = Sys.getCwd() + "/" + ENV_DEFAULT_bundledFolderPath;
		var manifestFilePath:String = targetFolderPath + "/" + MANIFEST_FILE_NAME;
		var currentManifestFingerprint:String = getCurrentLocalBundleFingerPrint(manifestFilePath);
		var bundledManifestFingerprint = getBundledManifest().fingerprint;
		if (currentManifestFingerprint != bundledManifestFingerprint) {
			USER_MESSAGE_INFO("Bundled resources are outdated or missing. Extracting bundled resources...");
			ensureBundledFileSystem(targetFolderPath);
		} else {
			USER_MESSAGE_INFO("Bundled resources are up-to-date. No extraction needed.");
		}
	}

	private static function ensureBundledFileSystem(targetFolderPath:String):Void {
		if (!FileSystem.exists(targetFolderPath)) {
			try {
				FileSystem.createDirectory(targetFolderPath);
			} catch (e:Dynamic) {
				USER_MESSAGE_ERROR("Failed to create directory: " + targetFolderPath + ". Error: " + Std.string(e));
				throw "Failed to create directory: " + targetFolderPath;
			}
		}

		var manifestContent:String = Json.stringify(getBundledManifest());
		File.saveContent(targetFolderPath + "/" + MANIFEST_FILE_NAME, manifestContent);

		var resourceBytes:haxe.io.Bytes = getResourceArchive();
		File.saveBytes(targetFolderPath + "/" + ARCHIVE_FILE_NAME, resourceBytes);

		Archive.extractArchive(targetFolderPath + "/" + ARCHIVE_FILE_NAME, targetFolderPath, function() {
			USER_MESSAGE_INFO("Bundled file system ensured at: " + targetFolderPath);

			// Cleanup

			var archiveFilePath:String = targetFolderPath + "/" + ARCHIVE_FILE_NAME;
			if (FileSystem.exists(archiveFilePath)) {
				try {
					FileSystem.deleteFile(archiveFilePath);
				} catch (e:Dynamic) {
					USER_MESSAGE_ERROR("Failed to delete archive file: " + archiveFilePath + ". Error: " + Std.string(e));
					throw "Failed to delete archive file: " + archiveFilePath;
				}
			}
		});
	}

	private static function getCurrentLocalBundleFingerPrint(manifestFilePath:String):String {
		if (!FileSystem.exists(manifestFilePath)) {
			USER_MESSAGE_ERROR("Manifest file does not exist at: " + manifestFilePath);
			return "";
		}

		var manifestContent = File.getContent(manifestFilePath);
		var manifestData:Dynamic = haxe.Json.parse(manifestContent);

		return manifestData.fingerprint;
	}

	public static function getBundledManifest():Dynamic {
		var manifestContent = haxe.Resource.getString(MANIFEST_FILE_NAME);
		if (manifestContent == null) {
			throw "Embedded manifest resource not found";
		}

		var content:Dynamic = haxe.Json.parse(manifestContent);
		return content;
	}

	public static function getResourceArchive():haxe.io.Bytes {
		var resourceBytes = haxe.Resource.getBytes(ARCHIVE_FILE_NAME);
		if (resourceBytes == null) {
			throw "Embedded resource archive not found";
		}
		return resourceBytes;
	}
}
