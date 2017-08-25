//
//  CardViewController.m
//  CardIO
//
//  Created by Fred on 7/11/16.
//  Copyright © 2016 Fred. All rights reserved.
//

#import "CardViewController.h"

#import <AVFoundation/AVFoundation.h>



@interface CardViewController ()

@end

@implementation CardViewController
{
    CIRectangleFeature *_borderDetectLastRectangleFeature;
}

- (CIRectangleFeature *)captureImageRectangle:(UIImage *)image{
    
    NSLog(@"26");
    CIImage *enhancedImage = [[CIImage alloc] initWithImage:image options:@{kCIImageColorSpace:[NSNull null]}];
    enhancedImage = [self filteredImageUsingContrastFilterOnImage:enhancedImage];
    CIRectangleFeature *rectangleFeature = [self biggestRectangleInRectangles:[[self highAccuracyRectangleDetector] featuresInImage:enhancedImage]];
    return rectangleFeature;

}

- (CIImage *)filteredImageUsingEnhanceFilterOnImage:(CIImage *)image
{
    return [CIFilter filterWithName:@"CIColorControls" keysAndValues:kCIInputImageKey, image, @"inputBrightness", [NSNumber numberWithFloat:0.0], @"inputContrast", [NSNumber numberWithFloat:1.14], @"inputSaturation", [NSNumber numberWithFloat:0.0], nil].outputImage;
}

- (CIImage *)filteredImageUsingContrastFilterOnImage:(CIImage *)image
{
    return [CIFilter filterWithName:@"CIColorControls" withInputParameters:@{@"inputContrast":@(1.1),kCIInputImageKey:image}].outputImage;
}

- (CIDetector *)highAccuracyRectangleDetector
{
    static CIDetector *detector = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
                  {
                      detector = [CIDetector detectorOfType:CIDetectorTypeRectangle context:nil options:@{CIDetectorAccuracy : CIDetectorAccuracyHigh}];
                  });
    return detector;
}

- (CIRectangleFeature *)biggestRectangleInRectangles:(NSArray *)rectangles
{
    if (![rectangles count]) return nil;
    
    float halfPerimiterValue = 0;
    
    CIRectangleFeature *biggestRectangle = [rectangles firstObject];
    
    for (CIRectangleFeature *rect in rectangles)
    {
        CGPoint p1 = rect.topLeft;
        CGPoint p2 = rect.topRight;
        CGFloat width = hypotf(p1.x - p2.x, p1.y - p2.y);
        
        CGPoint p3 = rect.topLeft;
        CGPoint p4 = rect.bottomLeft;
        CGFloat height = hypotf(p3.x - p4.x, p3.y - p4.y);
        
        CGFloat currentHalfPerimiterValue = height + width;
        
        if (halfPerimiterValue < currentHalfPerimiterValue)
        {
            halfPerimiterValue = currentHalfPerimiterValue;
            biggestRectangle = rect;
        }
        NSLog(@"79");
    }
    NSLog(@"81 %@",biggestRectangle);
    return biggestRectangle;
}

@end