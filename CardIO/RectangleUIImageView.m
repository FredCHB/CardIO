//
//  RectangleUIImageView.m
//  CardIO
//
//  Created by Fred on 7/13/16.
//  Copyright © 2016 Fred. All rights reserved.
//

#import "RectangleUIImageView.h"

@implementation RectangleUIImageView
@synthesize rectangle = _rectangle;

-(id)initWith{
    _rectangle = [CAShapeLayer layer];
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
