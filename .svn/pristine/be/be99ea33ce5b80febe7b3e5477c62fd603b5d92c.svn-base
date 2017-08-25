//
//  ViewController.h
//  CardIO
//
//  Created by Fred on 7/11/16.
//  Copyright © 2016 Fred. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RectangleUIImageView.h"
#import "Utils.h"



typedef NS_ENUM(NSInteger, ScanCardType) {
    TakePhoto = 1,
    ChoosePhoto
};

@interface ViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIActionSheetDelegate>

@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet UIView *footerView;
@property (strong, nonatomic) IBOutlet UIImageView *imagePicked;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topImagePicker;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomImagePicker;

@property (strong, nonatomic) UIImage *imageData;
@property ScanCardType previousType;

- (IBAction)openPhotoButton:(id)sender;
- (IBAction)saveImageButton:(id)sender;
@end

