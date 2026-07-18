

class Main {
    static function main():Void {
        Sys.println("Example: Resource Bundler implementation");

        // adding this line to the code will ensure that the bundled resources are unpacked to the target folder at runtime.
        // it will not unpack the resources if they are already unpacked, so it is safe to call this function multiple times.
        spilehx.projectmanagement.resourcebundler.ResourceBundler.unpackBundledResources();
    }
}

