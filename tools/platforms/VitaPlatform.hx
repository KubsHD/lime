package;

import hxp.Haxelib;
import hxp.HXML;
import hxp.Path;
import hxp.Log;
import hxp.NDLL;
import hxp.System;
import lime.tools.Architecture;
import lime.tools.AssetHelper;
import lime.tools.AssetType;
import lime.tools.CPPHelper;
import lime.tools.DeploymentHelper;
import lime.tools.HXProject;
import lime.tools.JavaHelper;
import lime.tools.NekoHelper;
import lime.tools.NodeJSHelper;
import lime.tools.Platform;
import lime.tools.PlatformTarget;
import lime.tools.ProjectHelper;
import sys.io.File;
import sys.io.Process;
import sys.FileSystem;

class VitaPlatform extends PlatformTarget
{
	private var applicationDirectory:String;
	private var executablePath:String;
	private var is64:Bool;
	private var isRaspberryPi:Bool;
	private var targetType:String;

	public function new(command:String, _project:HXProject, targetFlags:Map<String, String>)
	{
		super(command, _project, targetFlags);

		targetType = "cpp";

		targetDirectory = Path.combine(project.app.path, project.config.getString("vita.output-directory", "vita"));
		// targetDirectory = StringTools.replace(targetDirectory, "arch64", is64 ? "64" : "");
		applicationDirectory = targetDirectory + "/bin/";
		executablePath = Path.combine(applicationDirectory, project.app.file);
	}

	public override function build():Void
	{
		var hxml = targetDirectory + "/haxe/" + buildType + ".hxml";

		System.mkdir(targetDirectory);

		var haxeArgs = [hxml];
		var flags = [];

		flags.push("-Dtoolchain=vita");

		System.runCommand("", "haxe", haxeArgs.concat(["-D", "static_link"]));

		// if (noOutput) return;

		CPPHelper.compile(project, targetDirectory + "/obj", flags.concat(["-Dstatic_link", "-Dvita"]));
		CPPHelper.compile(project, targetDirectory + "/obj", flags, "BuildMain.xml");

		//System.copyFile(targetDirectory + "/obj/Main" + (project.debug ? "-debug" : ""), executablePath);

		System.runCommand("", "/usr/local/vitasdk/bin/vita-elf-create", [targetDirectory + "/obj/Main" + (project.debug ? "-debug" : "") + ".elf", targetDirectory + "/obj/Main.velf"]);
		System.runCommand("", "/usr/local/vitasdk/bin/vita-make-fself", ["-n -c", targetDirectory + "/obj/Main.velf", executablePath + "eboot.bin"]);


	}

	public override function clean():Void
	{
		if (FileSystem.exists(targetDirectory))
		{
			System.removeDirectory(targetDirectory);
		}
	}

	public override function deploy():Void
	{
		DeploymentHelper.deploy(project, targetFlags, targetDirectory, "Vita");
	}

	public override function display():Void
	{
		if (project.targetFlags.exists("output-file"))
		{
			Sys.println(executablePath);
		}
		else
		{
			Sys.println(getDisplayHXML().toString());
		}
	}

	private function generateContext():Dynamic
	{
		// var project = project.clone ();

		var context = project.templateContext;

		context.NEKO_FILE = targetDirectory + "/obj/ApplicationMain.n";
		context.NODE_FILE = targetDirectory + "/bin/ApplicationMain.js";
		context.HL_FILE = targetDirectory + "/obj/ApplicationMain.hl";
		context.CPP_DIR = targetDirectory + "/obj/";
		context.BUILD_DIR = project.app.path + "/vita";
		context.WIN_ALLOW_SHADERS = false;

		return context;
	}

	private function getDisplayHXML():HXML
	{
		var path = targetDirectory + "/haxe/" + buildType + ".hxml";

		if (FileSystem.exists(path))
		{
			return File.getContent(path);
		}
		else
		{
			var context = project.templateContext;
			var hxml = HXML.fromString(context.HAXE_FLAGS);
			hxml.addClassName(context.APP_MAIN);
			hxml.cpp = "_";
			hxml.noOutput = true;
			return hxml;
		}
	}

	public override function rebuild():Void
	{
		var commands = [];

		commands.push(["-Dtoolchain=vita", "-Dvita", "-Dstatic_link"]);

		CPPHelper.rebuild(project, commands);
	}

	public override function run():Void
	{
		var arguments = additionalArguments.copy();

		if (Log.verbose)
		{
			arguments.push("-verbose");
		}

		if (targetType == "nodejs")
		{
			NodeJSHelper.run(project, targetDirectory + "/bin/ApplicationMain.js", arguments);
		}
		else if (targetType == "java")
		{
			System.runCommand(applicationDirectory, "java", ["-jar", project.app.file + ".jar"].concat(arguments));
		}
		else if (project.target == cast System.hostPlatform)
		{
			arguments = arguments.concat(["-livereload"]);
			System.runCommand(applicationDirectory, "./" + Path.withoutDirectory(executablePath), arguments);
		}
	}

	public override function update():Void
	{
		AssetHelper.processLibraries(project, targetDirectory);

		// project = project.clone ();
		// initialize (project);

		for (asset in project.assets)
		{
			if (asset.embed && asset.sourcePath == "")
			{
				var path = Path.combine(targetDirectory + "/obj/tmp", asset.targetPath);
				System.mkdir(Path.directory(path));
				AssetHelper.copyAsset(asset, path);
				asset.sourcePath = path;
			}
		}

		if (project.targetFlags.exists("xml"))
		{
			project.haxeflags.push("-xml " + targetDirectory + "/types.xml");
		}

		var context = generateContext();
		context.OUTPUT_DIR = targetDirectory;


			for (i in 0...project.ndlls.length)
			{
				var ndll = project.ndlls[i];

				if (ndll.path == null || ndll.path == "")
				{
					context.ndlls[i].path = NDLL.getLibraryPath(ndll, "Vita", "lib", ".a", project.debug);
				}
			}


		System.mkdir(targetDirectory);
		System.mkdir(targetDirectory + "/obj");
		System.mkdir(targetDirectory + "/haxe");
		System.mkdir(applicationDirectory);

		// SWFHelper.generateSWFClasses (project, targetDirectory + "/haxe");

		ProjectHelper.recursiveSmartCopyTemplate(project, "haxe", targetDirectory + "/haxe", context);
		ProjectHelper.recursiveSmartCopyTemplate(project, targetType + "/hxml", targetDirectory + "/haxe", context);


		ProjectHelper.recursiveSmartCopyTemplate(project, "cpp/static", targetDirectory + "/obj", context);


		// context.HAS_ICON = IconHelper.createIcon (project.icons, 256, 256, Path.combine (applicationDirectory, "icon.png"));
		for (asset in project.assets)
		{
			var path = Path.combine(applicationDirectory, asset.targetPath);

			if (asset.embed != true)
			{
				if (asset.type != AssetType.TEMPLATE)
				{
					System.mkdir(Path.directory(path));
					AssetHelper.copyAssetIfNewer(asset, path);
				}
				else
				{
					System.mkdir(Path.directory(path));
					AssetHelper.copyAsset(asset, path, context);
				}
			}
		}
	}

	public override function watch():Void
	{
		var hxml = getDisplayHXML();
		var dirs = hxml.getClassPaths(true);

		var outputPath = Path.combine(Sys.getCwd(), project.app.path);
		dirs = dirs.filter(function(dir)
		{
			return (!Path.startsWith(dir, outputPath));
		});

		var command = ProjectHelper.getCurrentCommand();
		System.watch(command, dirs);
	}

	@ignore public override function install():Void {}

	@ignore public override function trace():Void {}

	@ignore public override function uninstall():Void {}
}
