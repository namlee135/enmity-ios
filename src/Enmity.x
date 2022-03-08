#import "Enmity.h"
#import "Utils.h"
#import "Plugins.h"

@interface AppDelegate
    @property (nonatomic, strong) UIWindow *window;
@end

%hook AppDelegate

- (id)sourceURLForBridge:(id)arg1 {
	id original = %orig;

	if (checkForUpdate()) {
		NSLog(@"Downloading Enmity.js to %@", ENMITY_PATH);
		BOOL success = downloadFile(ENMITY_URL, ENMITY_PATH);
		
		if (success) {
			NSLog(@"Downloaded");
		} else {
			alert(@"There was an error downloading Enmity.js, please try again.");
		}
	}

	return original;
}

- (void)startWithLaunchOptions:(id)options {
	%orig;
}

%end

%hook RCTCxxBridge 

- (void)executeApplicationScript:(NSData *)script url:(NSURL *)url async:(BOOL)async {
	if ([[url absoluteString] isEqualToString:@"tweak"]) {
		%orig;
		return;
	}

	// Apply modules patch
	NSString *modulesPatchCode = @"const oldObjectCreate = this.Object.create;"\
																"const _window = this;"\
																"_window.Object.create = (...args) => {"\
																"    const obj = oldObjectCreate.apply(_window.Object, args);"\
																"    if (args[0] === null) {"\
																"        _window.modules = obj;"\
																"        _window.Object.create = oldObjectCreate;"\
																"    }"\
																"    return obj;"\
																"};";

	NSData* modulesPatch = [modulesPatchCode dataUsingEncoding:NSUTF8StringEncoding];
	NSLog(@"Injecting modules patch");
	%orig(modulesPatch, [NSURL URLWithString:@"preload"], false);

	// Load bundle
	NSLog(@"Injecting bundle");
	%orig(script, url, false);

	if (!checkFileExists(ENMITY_PATH)) {
		alert(@"Enmity.js couldn't be found, please try restarting Discord.");
		return;
	}

	// Global values
	NSString *debugCode = [NSString stringWithFormat:@"window.enmity_debug = %s", IS_DEBUG ? "true" : "false"];
	%orig([debugCode dataUsingEncoding:NSUTF8StringEncoding], [NSURL URLWithString:@"debug"], false);
	%orig([@"window.plugins = {}; window.plugins.enabled = []; window.plugins.disabled = [];" dataUsingEncoding:NSUTF8StringEncoding], [NSURL URLWithString:@"plugins"], false);

	NSArray *themesList = getThemes();
	NSString *theme = getTheme();
	if (theme == nil) {
		theme = @"";
	}

	NSMutableArray *themes = [[NSMutableArray alloc] init];
	for (NSString *theme in themesList) {
		NSString *themeJson = getThemeJSON(theme);
		[themes addObject:themeJson];
	}

	NSString *themesCode = [NSString stringWithFormat:@"window.themes = {}; window.themes.list = [%@]; window.themes.theme = \"%@\";", [themes componentsJoinedByString:@","], theme];
	%orig([themesCode dataUsingEncoding:NSUTF8StringEncoding], [NSURL URLWithString:@"themes"], false);

	// Inject Enmity script
	NSError* error = nil;
	NSData* enmity = [NSData dataWithContentsOfFile:ENMITY_PATH options:0 error:&error];
	if (error) {
		NSLog(@"Couldn't load Enmity.js");
		return;
	}

	NSString *enmityCode = [[NSString alloc] initWithData:enmity encoding:NSUTF8StringEncoding];
	enmityCode = wrapPlugin(enmityCode, 9000, @"Enmity.js");
	
	NSLog(@"Injecting Enmity");
	%orig([enmityCode dataUsingEncoding:NSUTF8StringEncoding], [NSURL URLWithString:@"enmity"], false);

	// Load plugins
	NSArray* pluginsList = getPlugins();
	int pluginID = 9001;
	for (NSString *plugin in pluginsList) {
		NSString *pluginPath = getPluginPath(plugin);
		
		%orig([[NSString stringWithFormat:@"window.plugins.%s.push('%@')", isEnabled(pluginPath) ? "enabled" : "disabled", getPluginName([NSURL URLWithString:plugin])] dataUsingEncoding:NSUTF8StringEncoding], [NSURL URLWithString:@"plugins"], false);

		NSError* error = nil;
		NSData* pluginData = [NSData dataWithContentsOfFile:pluginPath options:0 error:&error];
		if (error) {
			NSLog(@"Couldn't load %@", plugin);
			continue;
		}

		NSString *pluginCode = [[NSString alloc] initWithData:pluginData encoding:NSUTF8StringEncoding];

		NSLog(@"Injecting %@", plugin);
		%orig([wrapPlugin(pluginCode, pluginID, plugin) dataUsingEncoding:NSUTF8StringEncoding], [NSURL URLWithString:plugin], false);
		pluginID += 1;
	}
}

%end

%ctor {
	createFolder(PLUGINS_PATH);
	createFolder(THEMES_PATH);
}