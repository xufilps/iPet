#!/usr/bin/env python3
"""Deterministically generate the small native Xcode project without third-party tooling."""
from pathlib import Path
import hashlib
root = Path(__file__).resolve().parents[1]
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
objects = {}
def obj(name, value): objects[ident(name)] = value; return ident(name)
def refs(names): return '(' + ', '.join(ident(n) for n in names) + ',)'
files = ['main.swift', 'AppModel.swift', 'ControlsView.swift', 'PetWindow.swift', 'ActivityView.swift', 'ShopView.swift', 'InventoryView.swift', 'PetSpeechWindow.swift', 'PetToolbarWindow.swift', 'PetMovementAreaWindow.swift', 'StatisticsView.swift', 'PackageView.swift', 'ScheduleView.swift', 'ShortcutView.swift', 'KeyboardMacroEditor.swift', 'DiagnosticsView.swift']
for f in files:
    obj(f, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = "<group>";')
    obj('build-' + f, f'isa = PBXBuildFile; fileRef = {ident(f)};')
obj('assets', 'isa = PBXFileReference; lastKnownFileType = folder; path = Resources/PetAssets; sourceTree = "<group>";')
obj('assets-build', f'isa = PBXBuildFile; fileRef = {ident("assets")};')
obj('icon-catalog', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Resources/Assets.xcassets; sourceTree = "<group>";')
obj('icon-catalog-build', f'isa = PBXBuildFile; fileRef = {ident("icon-catalog")};')
obj('attribution', 'isa = PBXFileReference; lastKnownFileType = text; path = ATTRIBUTION.md; sourceTree = "<group>";')
obj('attribution-build', f'isa = PBXBuildFile; fileRef = {ident("attribution")};')
obj('notice', 'isa = PBXFileReference; lastKnownFileType = text; name = NOTICE; path = ../NOTICE; sourceTree = "<group>";')
obj('notice-build', f'isa = PBXBuildFile; fileRef = {ident("notice")};')
obj('code-license', 'isa = PBXFileReference; lastKnownFileType = text; name = LICENSE; path = ../LICENSE; sourceTree = "<group>";')
obj('code-license-build', f'isa = PBXBuildFile; fileRef = {ident("code-license")};')
obj('animation-license', 'isa = PBXFileReference; lastKnownFileType = text; path = ANIMATION_LICENSE.md; sourceTree = "<group>";')
obj('animation-license-build', f'isa = PBXBuildFile; fileRef = {ident("animation-license")};')
obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = iPet.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('sources-group', f'isa = PBXGroup; children = {refs(files)}; path = Apps/macOS; sourceTree = "<group>";')
obj('products-group', f'isa = PBXGroup; children = {refs(["product"])}; name = Products; sourceTree = "<group>";')
obj('main-group', f'isa = PBXGroup; children = {refs(["sources-group", "assets", "icon-catalog", "attribution", "code-license", "notice", "animation-license", "products-group"])}; sourceTree = "<group>";')
obj('package', 'isa = XCLocalSwiftPackageReference; relativePath = .;')
for product in ['PetCore', 'PetRendering', 'PetMacInput']:
    obj('dep-' + product, f'isa = XCSwiftPackageProductDependency; productName = {product};')
    obj('link-' + product, f'isa = PBXBuildFile; productRef = {ident("dep-" + product)};')
obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {refs(["build-" + f for f in files])}; runOnlyForDeploymentPostprocessing = 0;')
obj('frameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {refs(["link-PetCore", "link-PetRendering", "link-PetMacInput"])}; runOnlyForDeploymentPostprocessing = 0;')
obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {refs(["assets-build", "icon-catalog-build", "attribution-build", "code-license-build", "notice-build", "animation-license-build"])}; runOnlyForDeploymentPostprocessing = 0;')
obj('convert', 'isa = PBXShellScriptBuildPhase; alwaysOutOfDate = 1; buildActionMask = 2147483647; files = (); inputPaths = (); outputPaths = (); name = "Convert built-in assets"; runOnlyForDeploymentPostprocessing = 0; shellPath = /bin/sh; shellScript = "set -eu\\n/usr/bin/python3 \\\"$SRCROOT/scripts/convert_assets.py\\\"\\n/usr/bin/python3 \\\"$SRCROOT/scripts/convert_gameplay.py\\\"\\n/usr/bin/python3 \\\"$SRCROOT/scripts/convert_dialogue.py\\\"\\n";')
for configuration in ['Debug', 'Release']:
    obj('project-' + configuration, f'isa = XCBuildConfiguration; name = {configuration}; buildSettings = {{ CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 6.0; MACOSX_DEPLOYMENT_TARGET = 26.0; SDKROOT = macosx; }};')
    obj('target-' + configuration, f'''isa = XCBuildConfiguration; name = {configuration}; buildSettings = {{
        ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
        PRODUCT_NAME = iPet; PRODUCT_BUNDLE_IDENTIFIER = org.xufilps.iPet;
        GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_LSUIElement = YES;
        INFOPLIST_KEY_CFBundleDisplayName = "iPet";
        MARKETING_VERSION = 0.2.0; CURRENT_PROJECT_VERSION = 2;
        SWIFT_VERSION = 6.0; MACOSX_DEPLOYMENT_TARGET = 26.0;
        CODE_SIGN_STYLE = Automatic; ENABLE_APP_SANDBOX = NO; ENABLE_USER_SCRIPT_SANDBOXING = NO;
        SWIFT_OPTIMIZATION_LEVEL = {"-Onone" if configuration == "Debug" else "-O"};
        LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";
    }};''')
obj('project-configs', f'isa = XCConfigurationList; buildConfigurations = {refs(["project-Debug", "project-Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('target-configs', f'isa = XCConfigurationList; buildConfigurations = {refs(["target-Debug", "target-Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {ident("target-configs")}; buildPhases = {refs(["convert", "sources", "frameworks", "resources"])}; buildRules = (); dependencies = (); name = iPet; packageProductDependencies = {refs(["dep-PetCore", "dep-PetRendering", "dep-PetMacInput"])}; productName = iPet; productReference = {ident("product")}; productType = "com.apple.product-type.application";')
obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {ident("project-configs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = "zh-Hans"; hasScannedForEncodings = 0; knownRegions = ("zh-Hans", en, Base,); mainGroup = {ident("main-group")}; packageReferences = {refs(["package"])}; productRefGroup = {ident("products-group")}; projectDirPath = ""; projectRoot = ""; targets = {refs(["target"])};')
text = '// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'
text += '\n'.join(f'{key} = {{ {value} }};' for key, value in objects.items())
text += '\n}; rootObject = ' + ident('project') + '; }\n'
(root / 'iPet.xcodeproj/project.pbxproj').write_text(text)
(root / 'iPet.xcodeproj/xcshareddata/xcschemes/iPet.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident('target')}" BuildableName="iPet.app" BlueprintName="iPet" ReferencedContainer="container:iPet.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident('target')}" BuildableName="iPet.app" BlueprintName="iPet" ReferencedContainer="container:iPet.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident('target')}" BuildableName="iPet.app" BlueprintName="iPet" ReferencedContainer="container:iPet.xcodeproj"/></BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
