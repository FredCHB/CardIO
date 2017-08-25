//
//  Utils.h
//  CardIO
//
//  Created by Fred on 10/27/16.
//  Copyright © 2016 Fred. All rights reserved.
//

#import <Foundation/Foundation.h>
@import UIKit;

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]
#define SCREEN_WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define SCREEN_HEIGHT ([[UIScreen mainScreen] bounds].size.height)

@interface Utils : NSObject
+ (Boolean)isIOSLeastVersion9;
@end
