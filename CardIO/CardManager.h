//
//  CardManager.h
//  CardIO
//
//  Created by Fred on 7/12/16.
//  Copyright © 2016 Fred. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

@interface CardManager : NSObject

+(CardManager *)getSharedInstance;
-(CIRectangleFeature *)captureImageRectangle:(UIImage *)image;
-(NSString *)captureImageCard:(UIImage *)image withCoordinates:(NSDictionary *)rectangleCoordinates rotateDegree:(CGFloat)rotateDegree;
@end
