#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "Commands.h"
#import "Plugins.h"
#import "Utils.h"
#import "Theme.h"

#define ENMITY_PATH [NSString stringWithFormat:@"%@/%@", NSHomeDirectory(), @"Documents/Enmity.js"]

// Define the URL used to download Enmity, also disable logs in release mode
#ifdef DEBUG
#		define ENMITY_URL @"http://192.168.1.150:8080/Enmity.js"
#   define IS_DEBUG true
#		define NSLog(fmt, ... ) NSLog((@"[Enmity-iOS] " fmt), ##__VA_ARGS__);
#else 
#		define ENMITY_URL @"https://files.enmity.app/Enmity.js"
#   define IS_DEBUG false
#		define NSLog(...) (void)0
#endif
