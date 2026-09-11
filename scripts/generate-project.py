#!/usr/bin/env python3
"""Rebuild the dependency-free Xcode project after adding/removing source files."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
objects = {}
def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(object_key, **value):
    objects[uid(object_key)] = value
    return uid(object_key)
def quote(value, level=0):
    indent = '\t' * level
    child_indent = '\t' * (level + 1)
    if isinstance(value, dict):
        if not value:
            return '{}'
        return '{\n' + '\n'.join(f'{child_indent}{json.dumps(k)} = {quote(v, level + 1)};' for k, v in value.items()) + '\n' + indent + '}'
    if isinstance(value, list):
        if not value:
            return '()'
        return '(\n' + '\n'.join(f'{child_indent}{quote(v, level + 1)},' for v in value) + '\n' + indent + ')'
    if isinstance(value, int):
        return str(value)
    return json.dumps(str(value))

app_files = sorted(root.glob('Savor/**/*.swift'))
test_files = sorted(root.glob('SavorUITests/*.swift'))
resources = [root / 'Shared/sample-recipes.json', root / 'Savor/Assets.xcassets', root / 'Savor/PrivacyInfo.xcprivacy']
groups = []
for name, files in [('App', app_files), ('Resources', resources), ('Tests', test_files)]:
    children = []
    for path in files:
        relative = str(path.relative_to(root))
        filetype = {'.swift': 'sourcecode.swift', '.json': 'text.json', '.xcassets': 'folder.assetcatalog', '.xcprivacy': 'text.xml'}[path.suffix]
        children.append(add(relative, isa='PBXFileReference', lastKnownFileType=filetype, path=relative, sourceTree='<group>'))
        add(relative + ':build', isa='PBXBuildFile', fileRef=uid(relative))
    groups.append(add(name, isa='PBXGroup', name=name, children=children, sourceTree='<group>'))

app_product = add('product-app', isa='PBXFileReference', explicitFileType='wrapper.application', path='Savor.app', sourceTree='BUILT_PRODUCTS_DIR', includeInIndex=0)
test_product = add('product-test', isa='PBXFileReference', explicitFileType='wrapper.cfbundle', path='SavorUITests.xctest', sourceTree='BUILT_PRODUCTS_DIR', includeInIndex=0)
groups.append(add('Products', isa='PBXGroup', name='Products', children=[app_product, test_product], sourceTree='<group>'))
main_group = add('Main', isa='PBXGroup', children=groups, sourceTree='<group>')

def build_phase(name, isa, files):
    return add(name, isa=isa, buildActionMask=2147483647, files=[uid(str(f.relative_to(root)) + ':build') for f in files], runOnlyForDeploymentPostprocessing=0)

app_phases = [build_phase('app-sources', 'PBXSourcesBuildPhase', app_files), build_phase('app-resources', 'PBXResourcesBuildPhase', resources), build_phase('app-frameworks', 'PBXFrameworksBuildPhase', [])]
test_phases = [build_phase('test-sources', 'PBXSourcesBuildPhase', test_files), build_phase('test-frameworks', 'PBXFrameworksBuildPhase', [])]

def configurations(name, common):
    ids = []
    for config in ['Debug', 'Release']:
        settings = dict(common)
        if name == 'app':
            settings.update({'SAVOR_SERVER_URL': '', 'SAVOR_CLIENT_TOKEN': ''})
        settings.update({'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if config == 'Debug' else '-O', 'DEBUG_INFORMATION_FORMAT': 'dwarf' if config == 'Debug' else 'dwarf-with-dsym'})
        if config == 'Debug':
            settings.update({'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG $(inherited)', 'ENABLE_TESTABILITY': 'YES', 'ONLY_ACTIVE_ARCH': 'YES'})
        extra = {}
        if name == 'app' and config == 'Debug':
            extra['baseConfigurationReference'] = uid('debug-config')
            settings.pop('SAVOR_SERVER_URL', None)
            settings.pop('SAVOR_CLIENT_TOKEN', None)
        ids.append(add(name + config, isa='XCBuildConfiguration', name=config, buildSettings=settings, **extra))
    return add(name + '-config', isa='XCConfigurationList', buildConfigurations=ids, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')

add('debug-config', isa='PBXFileReference', lastKnownFileType='text.xcconfig', path='Debug.xcconfig', sourceTree='<group>')
project_config = configurations('project', {'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES', 'SWIFT_VERSION': '5.0', 'SDKROOT': 'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0', 'GCC_C_LANGUAGE_STANDARD': 'gnu17', 'CLANG_WARN_DOCUMENTATION_COMMENTS': 'YES', 'ENABLE_USER_SCRIPT_SANDBOXING': 'YES'})
app_config = configurations('app', {'PRODUCT_BUNDLE_IDENTIFIER': 'com.lawrenceliu.savor', 'PRODUCT_NAME': '$(TARGET_NAME)', 'INFOPLIST_FILE': 'Savor/Info.plist', 'GENERATE_INFOPLIST_FILE': 'NO', 'TARGETED_DEVICE_FAMILY': '1', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'SUPPORTS_MACCATALYST': 'NO', 'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD': 'NO', 'CODE_SIGN_STYLE': 'Automatic', 'DEVELOPMENT_TEAM': '', 'MARKETING_VERSION': '0.1.0', 'CURRENT_PROJECT_VERSION': '1', 'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon', 'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/Frameworks']})
test_config = configurations('tests', {'PRODUCT_BUNDLE_IDENTIFIER': 'com.lawrenceliu.savor.uitests', 'PRODUCT_NAME': '$(TARGET_NAME)', 'GENERATE_INFOPLIST_FILE': 'YES', 'TEST_TARGET_NAME': 'Savor', 'TARGETED_DEVICE_FAMILY': '1', 'CODE_SIGN_STYLE': 'Automatic', 'DEVELOPMENT_TEAM': '', 'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']})

app_target = add('target-app', isa='PBXNativeTarget', name='Savor', productName='Savor', productReference=app_product, productType='com.apple.product-type.application', buildConfigurationList=app_config, buildPhases=app_phases, buildRules=[], dependencies=[])
proxy = add('proxy', isa='PBXContainerItemProxy', containerPortal=uid('project'), proxyType=1, remoteGlobalIDString=app_target, remoteInfo='Savor')
dependency = add('dependency', isa='PBXTargetDependency', target=app_target, targetProxy=proxy)
test_target = add('target-test', isa='PBXNativeTarget', name='SavorUITests', productName='SavorUITests', productReference=test_product, productType='com.apple.product-type.bundle.ui-testing', buildConfigurationList=test_config, buildPhases=test_phases, buildRules=[], dependencies=[dependency])
project = add('project', isa='PBXProject', attributes={'BuildIndependentTargetsInParallel': 'YES', 'LastUpgradeCheck': '2610', 'TargetAttributes': {app_target: {'CreatedOnToolsVersion': '26.1.1'}, test_target: {'CreatedOnToolsVersion': '26.1.1', 'TestTargetID': app_target}}}, buildConfigurationList=project_config, compatibilityVersion='Xcode 14.0', developmentRegion='en', hasScannedForEncodings=0, knownRegions=['en', 'Base'], mainGroup=main_group, productRefGroup=uid('Products'), projectDirPath='', projectRoot='', targets=[app_target, test_target])
project_dir = root / 'Savor.xcodeproj'
project_dir.mkdir(exist_ok=True)
(project_dir / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + quote({'archiveVersion': 1, 'classes': {}, 'objectVersion': 56, 'objects': objects, 'rootObject': project}) + '\n')

scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2610" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
  <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="Savor.app" BlueprintName="Savor" ReferencedContainer="container:Savor.xcodeproj"/></BuildActionEntry>
 </BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_target}" BuildableName="SavorUITests.xctest" BlueprintName="SavorUITests" ReferencedContainer="container:Savor.xcodeproj"/></TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="Savor.app" BlueprintName="Savor" ReferencedContainer="container:Savor.xcodeproj"/></BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="Savor.app" BlueprintName="Savor" ReferencedContainer="container:Savor.xcodeproj"/></BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
scheme_dir = project_dir / 'xcshareddata/xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)
(scheme_dir / 'Savor.xcscheme').write_text(scheme)
print(f'Generated Savor.xcodeproj ({len(app_files)} Swift source files).')
