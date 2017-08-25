//
//  Utils.m
//  CardIO
//
//  Created by Fred on 10/27/16.
//  Copyright © 2016 Fred. All rights reserved.
//

#import "Utils.h"

@implementation Utils

+ (Boolean)isIOSLeastVersion9 {
    NSComparisonResult order = [[UIDevice currentDevice].systemVersion compare: @"9.0" options: NSNumericSearch];
    if (order == NSOrderedSame || order == NSOrderedDescending) {
        // OS version >= 9.0
        return YES;
    } else {
        // OS version < 9.0
        return NO;
    }
}
@end
