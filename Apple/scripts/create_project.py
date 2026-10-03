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
ios_files = ['iPetApp.swift', 'IOSPetModel.swift', 'PetStageView.swift', 'HomeView.swift', 'ActivitiesView.swift', 'MarketView.swift', 'SettingsView.swift']
for f in ios_files:
    obj('ios-' + f, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = "<group>";')
    obj('ios-build-' + f, f'isa = PBXBuildFile; fileRef = {ident("ios-" + f)};')
obj('ios-sources-group', f'isa = PBXGroup; children = {refs(["ios-" + f for f in ios_files])}; path = Apps/iOS; sourceTree = "<group>";')
obj('ios-product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = "iPet-iOS.app"; sourceTree = BUILT_PRODUCTS_DIR;')
obj('ios-icon-catalog', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Resources/iOSAssets.xcassets; sourceTree = "<group>";')
obj('ios-icon-build', f'isa = PBXBuildFile; fileRef = {ident("ios-icon-catalog")};')
for product in ['PetCore', 'PetRendering']:
    obj('ios-dep-' + product, f'isa = XCSwiftPackageProductDependency; productName = {product};')
    obj('ios-link-' + product, f'isa = PBXBuildFile; productRef = {ident("ios-dep-" + product)};')
obj('ios-sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {refs(["ios-build-" + f for f in ios_files])}; runOnlyForDeploymentPostprocessing = 0;')
obj('ios-frameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {refs(["ios-link-PetCore", "ios-link-PetRendering"])}; runOnlyForDeploymentPostprocessing = 0;')
obj('ios-resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {refs(["assets-build", "ios-icon-build", "attribution-build", "code-license-build", "notice-build", "animation-license-build"])}; runOnlyForDeploymentPostprocessing = 0;')
obj('ios-convert', objects[ident('convert')])
for configuration in ['Debug', 'Release']:
    obj('ios-target-' + configuration, f'''isa = XCBuildConfiguration; name = {configuration}; buildSettings = {{
        ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
        PRODUCT_NAME = "iPet-iOS"; PRODUCT_BUNDLE_IDENTIFIER = org.xufilps.iPet.ios;
        GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_CFBundleDisplayName = "iPet";
        INFOPLIST_KEY_UILaunchScreen_Generation = YES;
        INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
        INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
        MARKETING_VERSION = 0.2.0; CURRENT_PROJECT_VERSION = 2;
        SWIFT_VERSION = 6.0; IPHONEOS_DEPLOYMENT_TARGET = 26.0; SDKROOT = iphoneos;
        ONLY_ACTIVE_ARCH = {"YES" if configuration == "Debug" else "NO"}; ENABLE_TESTABILITY = {"YES" if configuration == "Debug" else "NO"};
        TARGETED_DEVICE_FAMILY = "1,2"; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
        CODE_SIGN_STYLE = Automatic; ENABLE_USER_SCRIPT_SANDBOXING = NO;
        SWIFT_OPTIMIZATION_LEVEL = {"-Onone" if configuration == "Debug" else "-O"};
        LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
    }};''')
obj('ios-target-configs', f'isa = XCConfigurationList; buildConfigurations = {refs(["ios-target-Debug", "ios-target-Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('ios-target', f'isa = PBXNativeTarget; buildConfigurationList = {ident("ios-target-configs")}; buildPhases = {refs(["ios-convert", "ios-sources", "ios-frameworks", "ios-resources"])}; buildRules = (); dependencies = (); name = "iPet-iOS"; packageProductDependencies = {refs(["ios-dep-PetCore", "ios-dep-PetRendering"])}; productName = "iPet-iOS"; productReference = {ident("ios-product")}; productType = "com.apple.product-type.application";')
obj('products-group', f'isa = PBXGroup; children = {refs(["product", "ios-product"])}; name = Products; sourceTree = "<group>";')
obj('main-group', f'isa = PBXGroup; children = {refs(["sources-group", "ios-sources-group", "assets", "icon-catalog", "ios-icon-catalog", "attribution", "code-license", "notice", "animation-license", "products-group"])}; sourceTree = "<group>";')
obj('ios-test-file', 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Tests/iOSAppTests/IOSPetModelTests.swift; sourceTree = "<group>";')
obj('ios-test-build', f'isa = PBXBuildFile; fileRef = {ident("ios-test-file")};')
obj('ios-test-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = "iPet-iOSTests.xctest"; sourceTree = BUILT_PRODUCTS_DIR;')
obj('ios-test-sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {refs(["ios-test-build"])}; runOnlyForDeploymentPostprocessing = 0;')
obj('ios-test-frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj('ios-test-dependency', f'isa = PBXTargetDependency; target = {ident("ios-target")};')
for configuration in ['Debug', 'Release']:
    obj('ios-test-' + configuration, f'''isa = XCBuildConfiguration; name = {configuration}; buildSettings = {{
        PRODUCT_NAME = "iPet-iOSTests"; PRODUCT_BUNDLE_IDENTIFIER = org.xufilps.iPet.ios.tests;
        GENERATE_INFOPLIST_FILE = YES; SWIFT_VERSION = 6.0; IPHONEOS_DEPLOYMENT_TARGET = 26.0; SDKROOT = iphoneos;
        ONLY_ACTIVE_ARCH = {"YES" if configuration == "Debug" else "NO"}; ENABLE_TESTABILITY = {"YES" if configuration == "Debug" else "NO"};
        TARGETED_DEVICE_FAMILY = "1,2"; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
        TEST_HOST = "$(BUILT_PRODUCTS_DIR)/iPet-iOS.app/iPet-iOS"; BUNDLE_LOADER = "$(TEST_HOST)";
        CODE_SIGN_STYLE = Automatic; SWIFT_OPTIMIZATION_LEVEL = {"-Onone" if configuration == "Debug" else "-O"};
        LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @loader_path/Frameworks";
    }};''')
obj('ios-test-configs', f'isa = XCConfigurationList; buildConfigurations = {refs(["ios-test-Debug", "ios-test-Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('ios-test-target', f'isa = PBXNativeTarget; buildConfigurationList = {ident("ios-test-configs")}; buildPhases = {refs(["ios-test-sources", "ios-test-frameworks"])}; buildRules = (); dependencies = {refs(["ios-test-dependency"])}; name = "iPet-iOSTests"; productName = "iPet-iOSTests"; productReference = {ident("ios-test-product")}; productType = "com.apple.product-type.bundle.unit-test";')
obj('main-group', objects[ident('main-group')].replace('children = (', 'children = ('+ident('ios-test-file')+', '))
obj('products-group', f'isa = PBXGroup; children = {refs(["product", "ios-product", "ios-test-product"])}; name = Products; sourceTree = "<group>";')
obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {ident("project-configs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = "zh-Hans"; hasScannedForEncodings = 0; knownRegions = ("zh-Hans", en, Base,); mainGroup = {ident("main-group")}; packageReferences = {refs(["package"])}; productRefGroup = {ident("products-group")}; projectDirPath = ""; projectRoot = ""; targets = {refs(["target", "ios-target", "ios-test-target"])};')
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

# The iOS application uses the same shared scheme structure, with a distinct target/product.
mac_scheme = (root / 'iPet.xcodeproj/xcshareddata/xcschemes/iPet.xcscheme').read_text()
(root / 'iPet.xcodeproj/xcshareddata/xcschemes/iPet-iOS.xcscheme').write_text(
    mac_scheme.replace(ident('target'), ident('ios-target')).replace('BuildableName="iPet.app"', 'BuildableName="iPet-iOS.app"').replace('BlueprintName="iPet"', 'BlueprintName="iPet-iOS"')
)

ios_scheme_path = root / 'iPet.xcodeproj/xcshareddata/xcschemes/iPet-iOS.xcscheme'
ios_scheme = ios_scheme_path.read_text()
ios_scheme = ios_scheme.replace('<LaunchAction', f'''<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident('ios-test-target')}" BuildableName="iPet-iOSTests.xctest" BlueprintName="iPet-iOSTests" ReferencedContainer="container:iPet.xcodeproj"/></TestableReference></Testables></TestAction>\n<LaunchAction''')
ios_scheme_path.write_text(ios_scheme)
