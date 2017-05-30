import Development.Shake
import Development.Shake.Command
import Development.Shake.FilePath
import Development.Shake.Util
import System.Exit
import System.Directory

type ToolchainSpec = String

data Target = Target {
    targetName :: String,
    targetToolchain :: ToolchainSpec
    }

data Package = Package {
    packageName :: String,
    archiveName :: String
    }

cmdIn :: String -> String -> Action ()
cmdIn directory commandString = cmd "sh" ["-c", "cd " ++ directory ++ "&&" ++ commandString]

usingPackage :: String -> String -> String -> Rules String
usingPackage name version archive =
    let fullName = name ++ "-" ++ version
        principalFile = "build/host/packages" </> name </> "destdir/lib/pkgconfig" </> name ++ ".pc"
        packageDir = "build/host/packages" </> name
        rootDir = packageDir </> fullName
    in do
        cwd <- liftIO getCurrentDirectory
        principalFile %> \_ -> do
            need [rootDir </> "Makefile"]
            cmdIn rootDir ("make -j8 && make DESTDIR=" ++ cwd </> "build/host/packages" </> name </> "destdir install")

        rootDir </> "Makefile" %> \_ -> do
            need [rootDir </> "configure"]
            cmdIn rootDir "./configure --prefix=/"

        rootDir </> "configure" %> \_ -> do
            need ["downloads" </> archive]
            cmd "tar" ["-xvf",  "downloads" </> archive, "-C", packageDir]

        return principalFile

main :: IO ()
main = shakeArgs shakeOptions{shakeFiles="_shake"} $ do
    isl <- usingPackage "isl" "0.18" "isl-0.18.tar.xz"
    binutils <- usingPackage "binutils" "2.28" "binutils-2.28.tar.bz2"

    want [isl, binutils]
