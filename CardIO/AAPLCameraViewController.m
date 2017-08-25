/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
View controller for camera interface.
*/

@import AVFoundation;
@import Photos;

#import "AAPLCameraViewController.h"
#import "AAPLPreviewView.h"
#import "ViewController.h"

static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * SessionRunningContext = &SessionRunningContext;

typedef NS_ENUM( NSInteger, AVCamSetupResult ) {
	AVCamSetupResultSuccess,
	AVCamSetupResultCameraNotAuthorized,
	AVCamSetupResultSessionConfigurationFailed
};

@interface AAPLCameraViewController ()

// For use in the storyboards.
@property (weak, nonatomic) IBOutlet AAPLPreviewView *previewView;
@property (weak, nonatomic) IBOutlet UIButton *stillButton;
@property (weak, nonatomic) IBOutlet UILabel *cameraUnavailableLabel;
@property (weak, nonatomic) IBOutlet UIButton *resumeButton;


// Session management.
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;

// Utilities.
@property (nonatomic) AVCamSetupResult setupResult;
@property (nonatomic, getter=isSessionRunning) BOOL sessionRunning;

@end

@implementation AAPLCameraViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
    
    self.navigationController.navigationBar.hidden = YES;

	// Disable UI. The UI is enabled if and only if the session starts running.
	self.stillButton.enabled = NO;

	// Create the AVCaptureSession.
	self.session = [[AVCaptureSession alloc] init];

	// Setup the preview view.
	self.previewView.session = self.session;

	// Communicate with the session and other session objects on this queue.
	self.sessionQueue = dispatch_queue_create( "session queue", DISPATCH_QUEUE_SERIAL );

	self.setupResult = AVCamSetupResultSuccess;

	// Check video authorization status. Video access is required and audio access is optional.
	// If audio access is denied, audio is not recorded during movie recording.
	switch ( [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] )
	{
		case AVAuthorizationStatusAuthorized:
		{
			// The user has previously granted access to the camera.
			break;
		}
		case AVAuthorizationStatusNotDetermined:
		{
			// The user has not yet been presented with the option to grant video access.
			// We suspend the session queue to delay session setup until the access request has completed to avoid
			// asking the user for audio access if video access is denied.
			// Note that audio access will be implicitly requested when we create an AVCaptureDeviceInput for audio during session setup.
			dispatch_suspend( self.sessionQueue );
			[AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^( BOOL granted ) {
				if ( ! granted ) {
					self.setupResult = AVCamSetupResultCameraNotAuthorized;
				}
				dispatch_resume( self.sessionQueue );
			}];
			break;
		}
		default:
		{
			// The user has previously denied access.
			self.setupResult = AVCamSetupResultCameraNotAuthorized;
			break;
		}
	}

	// Setup the capture session.
	// In general it is not safe to mutate an AVCaptureSession or any of its inputs, outputs, or connections from multiple threads at the same time.
	// Why not do all of this on the main queue?
	// Because -[AVCaptureSession startRunning] is a blocking call which can take a long time. We dispatch session setup to the sessionQueue
	// so that the main queue isn't blocked, which keeps the UI responsive.
	dispatch_async( self.sessionQueue, ^{
		if ( self.setupResult != AVCamSetupResultSuccess ) {
			return;
		}

		NSError *error = nil;

		AVCaptureDevice *videoDevice = [AAPLCameraViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
		AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];

		if ( ! videoDeviceInput ) {
			NSLog( @"Could not create video device input: %@", error );
		}

		[self.session beginConfiguration];

		if ( [self.session canAddInput:videoDeviceInput] ) {
			[self.session addInput:videoDeviceInput];
			self.videoDeviceInput = videoDeviceInput;

			dispatch_async( dispatch_get_main_queue(), ^{
				// Why are we dispatching this to the main queue?
				// Because AVCaptureVideoPreviewLayer is the backing layer for AAPLPreviewView and UIView
				// can only be manipulated on the main thread.
				// Note: As an exception to the above rule, it is not necessary to serialize video orientation changes
				// on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.

				// Use the status bar orientation as the initial video orientation. Subsequent orientation changes are handled by
				// -[viewWillTransitionToSize:withTransitionCoordinator:].
				UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
				AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationPortrait;
				if ( statusBarOrientation != UIInterfaceOrientationUnknown ) {
					initialVideoOrientation = (AVCaptureVideoOrientation)statusBarOrientation;
				}

				AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
				previewLayer.connection.videoOrientation = initialVideoOrientation;
                previewLayer.videoGravity = AVLayerVideoGravityResize;

			} );
		}
		else {
			NSLog( @"Could not add video device input to the session" );
			self.setupResult = AVCamSetupResultSessionConfigurationFailed;
		}

//		AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
//		AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
//
//		if ( ! audioDeviceInput ) {
//			NSLog( @"Could not create audio device input: %@", error );
//		}
//
//		if ( [self.session canAddInput:audioDeviceInput] ) {
//			[self.session addInput:audioDeviceInput];
//		}
//		else {
//			NSLog( @"Could not add audio device input to the session" );
//		}

		AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
		if ( [self.session canAddOutput:stillImageOutput] ) {
			stillImageOutput.outputSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};
			[self.session addOutput:stillImageOutput];
			self.stillImageOutput = stillImageOutput;
		}
		else {
			NSLog( @"Could not add still image output to the session" );
			self.setupResult = AVCamSetupResultSessionConfigurationFailed;
		}

		[self.session commitConfiguration];
	} );
}

-(BOOL)prefersStatusBarHidden{
    return YES;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	dispatch_async( self.sessionQueue, ^{
		switch ( self.setupResult )
		{
			case AVCamSetupResultSuccess:
			{
				// Only setup observers and start the session running if setup succeeded.
				[self addObservers];
				[self.session startRunning];
				self.sessionRunning = self.session.isRunning;
				break;
			}
			case AVCamSetupResultCameraNotAuthorized:
			{
				dispatch_async( dispatch_get_main_queue(), ^{
					NSString *message = NSLocalizedString( @"AVCam doesn't have permission to use the camera, please change privacy settings", @"Alert message when the user has denied access to the camera" );
					UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
					UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
					[alertController addAction:cancelAction];
					// Provide quick access to Settings.
					UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"Settings", @"Alert button to open Settings" ) style:UIAlertActionStyleDefault handler:^( UIAlertAction *action ) {
						[[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
					}];
					[alertController addAction:settingsAction];
					[self presentViewController:alertController animated:YES completion:nil];
				} );
				break;
			}
			case AVCamSetupResultSessionConfigurationFailed:
			{
				dispatch_async( dispatch_get_main_queue(), ^{
					NSString *message = NSLocalizedString( @"Unable to capture media", @"Alert message when something goes wrong during capture session configuration" );
					UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
					UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
					[alertController addAction:cancelAction];
					[self presentViewController:alertController animated:YES completion:nil];
				} );
				break;
			}
		}
	} );
}

- (void)viewDidDisappear:(BOOL)animated
{
	dispatch_async( self.sessionQueue, ^{
		if ( self.setupResult == AVCamSetupResultSuccess ) {
			[self.session stopRunning];
			[self removeObservers];
		}
	} );

	[super viewDidDisappear:animated];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

	// Note that the app delegate controls the device orientation notifications required to use the device orientation.
	UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
	if ( UIDeviceOrientationIsPortrait( deviceOrientation ) || UIDeviceOrientationIsLandscape( deviceOrientation ) ) {
		AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
		previewLayer.connection.videoOrientation = (AVCaptureVideoOrientation)deviceOrientation;
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
	}
}

#pragma mark KVO and Notifications

- (void)addObservers
{
	[self.session addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:SessionRunningContext];
	[self.stillImageOutput addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:CapturingStillImageContext];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.videoDeviceInput.device];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self.session];
	// A session can only run when the app is full screen. It will be interrupted in a multi-app layout, introduced in iOS 9,
	// see also the documentation of AVCaptureSessionInterruptionReason. Add observers to handle these session interruptions
	// and show a preview is paused message. See the documentation of AVCaptureSessionWasInterruptedNotification for other
	// interruption reasons.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:self.session];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:self.session];
}

- (void)removeObservers
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[self.session removeObserver:self forKeyPath:@"running" context:SessionRunningContext];
	[self.stillImageOutput removeObserver:self forKeyPath:@"capturingStillImage" context:CapturingStillImageContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ( context == CapturingStillImageContext ) {
		BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];

		if ( isCapturingStillImage ) {
			dispatch_async( dispatch_get_main_queue(), ^{
				self.previewView.layer.opacity = 0.0;
				[UIView animateWithDuration:0.25 animations:^{
					self.previewView.layer.opacity = 1.0;
				}];
			} );
		}
	}
	else if ( context == SessionRunningContext ) {
		BOOL isSessionRunning = [change[NSKeyValueChangeNewKey] boolValue];

		dispatch_async( dispatch_get_main_queue(), ^{
			// Only enable the ability to change camera if the device has more than one camera.
			self.stillButton.enabled = isSessionRunning;
		} );
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)subjectAreaDidChange:(NSNotification *)notification
{
	CGPoint devicePoint = CGPointMake( 0.5, 0.5 );
	[self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

- (void)sessionRuntimeError:(NSNotification *)notification
{
	NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
	NSLog( @"Capture session runtime error: %@", error );

	// Automatically try to restart the session running if media services were reset and the last start running succeeded.
	// Otherwise, enable the user to try to resume the session running.
	if ( error.code == AVErrorMediaServicesWereReset ) {
		dispatch_async( self.sessionQueue, ^{
			if ( self.isSessionRunning ) {
				[self.session startRunning];
				self.sessionRunning = self.session.isRunning;
			}
			else {
				dispatch_async( dispatch_get_main_queue(), ^{
					self.resumeButton.hidden = NO;
				} );
			}
		} );
	}
	else {
		self.resumeButton.hidden = NO;
	}
}

- (void)sessionWasInterrupted:(NSNotification *)notification
{
	// In some scenarios we want to enable the user to resume the session running.
	// For example, if music playback is initiated via control center while using AVCam,
	// then the user can let AVCam resume the session running, which will stop music playback.
	// Note that stopping music playback in control center will not automatically resume the session running.
	// Also note that it is not always possible to resume, see -[resumeInterruptedSession:].
	BOOL showResumeButton = NO;

	// In iOS 9 and later, the userInfo dictionary contains information on why the session was interrupted.
	if ( &AVCaptureSessionInterruptionReasonKey ) {
		AVCaptureSessionInterruptionReason reason = [notification.userInfo[AVCaptureSessionInterruptionReasonKey] integerValue];
		NSLog( @"Capture session was interrupted with reason %ld", (long)reason );

		if ( reason == AVCaptureSessionInterruptionReasonAudioDeviceInUseByAnotherClient ||
			 reason == AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient ) {
			showResumeButton = YES;
		}
		else if ( reason == AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps ) {
			// Simply fade-in a label to inform the user that the camera is unavailable.
			self.cameraUnavailableLabel.hidden = NO;
			self.cameraUnavailableLabel.alpha = 0.0;
			[UIView animateWithDuration:0.25 animations:^{
				self.cameraUnavailableLabel.alpha = 1.0;
			}];
		}
	}
	else {
		NSLog( @"Capture session was interrupted" );
		showResumeButton = ( [UIApplication sharedApplication].applicationState == UIApplicationStateInactive );
	}

	if ( showResumeButton ) {
		// Simply fade-in a button to enable the user to try to resume the session running.
		self.resumeButton.hidden = NO;
		self.resumeButton.alpha = 0.0;
		[UIView animateWithDuration:0.25 animations:^{
			self.resumeButton.alpha = 1.0;
		}];
	}
}

- (void)sessionInterruptionEnded:(NSNotification *)notification
{
	NSLog( @"Capture session interruption ended" );

	if ( ! self.resumeButton.hidden ) {
		[UIView animateWithDuration:0.25 animations:^{
			self.resumeButton.alpha = 0.0;
		} completion:^( BOOL finished ) {
			self.resumeButton.hidden = YES;
		}];
	}
	if ( ! self.cameraUnavailableLabel.hidden ) {
		[UIView animateWithDuration:0.25 animations:^{
			self.cameraUnavailableLabel.alpha = 0.0;
		} completion:^( BOOL finished ) {
			self.cameraUnavailableLabel.hidden = YES;
		}];
	}
}

#pragma mark Actions

- (IBAction)resumeInterruptedSession:(id)sender
{
	dispatch_async( self.sessionQueue, ^{
		// The session might fail to start running, e.g., if a phone or FaceTime call is still using audio or video.
		// A failure to start the session running will be communicated via a session runtime error notification.
		// To avoid repeatedly failing to start the session running, we only try to restart the session running in the
		// session runtime error handler if we aren't trying to resume the session running.
		[self.session startRunning];
		self.sessionRunning = self.session.isRunning;
		if ( ! self.session.isRunning ) {
			dispatch_async( dispatch_get_main_queue(), ^{
				NSString *message = NSLocalizedString( @"Unable to resume", @"Alert message when unable to resume the session running" );
				UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
				UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
				[alertController addAction:cancelAction];
				[self presentViewController:alertController animated:YES completion:nil];
			} );
		}
		else {
			dispatch_async( dispatch_get_main_queue(), ^{
				self.resumeButton.hidden = YES;
			} );
		}
	} );
}


-(UIImage *)getRecentPhotoFromCamera{
    
    PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
    requestOptions.resizeMode   = PHImageRequestOptionsResizeModeExact;
    requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    requestOptions.synchronous = true;
    PHFetchResult *result = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil];
    
    NSLog(@"%d",(int)result.count);
    
    PHImageManager *manager = [PHImageManager defaultManager];
    
    // assets contains PHAsset objects.
    
    __block UIImage *ima;
    PHAsset *asset = [result lastObject];
    [manager requestImageForAsset:asset
                       targetSize:PHImageManagerMaximumSize
                      contentMode:PHImageContentModeDefault
                          options:requestOptions
                    resultHandler:^void(UIImage *image, NSDictionary *info) {
                        ima = image;
                    }];
    return ima;
}

- (IBAction)closeButton:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)snapStillImage:(id)sender {
    
    dispatch_async( self.sessionQueue, ^{
        AVCaptureConnection *connection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
        AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.previewView.layer;
        
        // Update the orientation on the still image output video connection before capturing.
        connection.videoOrientation = previewLayer.connection.videoOrientation;
        
        // Flash set to Auto for Still Capture.
        [AAPLCameraViewController setFlashMode:AVCaptureFlashModeAuto forDevice:self.videoDeviceInput.device];
        
        // Capture a still image.
        [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^( CMSampleBufferRef imageDataSampleBuffer, NSError *error ) {
            if ( imageDataSampleBuffer ) {
                // The sample buffer is not retained. Create image data before saving the still image to the photo library asynchronously.
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                [PHPhotoLibrary requestAuthorization:^( PHAuthorizationStatus status ) {
                    if ( status == PHAuthorizationStatusAuthorized ) {
                        // To preserve the metadata, we create an asset from the JPEG NSData representation.
                        // Note that creating an asset from a UIImage discards the metadata.
                        // In iOS 9, we can use -[PHAssetCreationRequest addResourceWithType:data:options].
                        // In iOS 8, we save the image to a temporary file and use +[PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:].
                        if ( [PHAssetCreationRequest class] ) {
                            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                [[PHAssetCreationRequest creationRequestForAsset] addResourceWithType:PHAssetResourceTypePhoto data:imageData options:nil];
                            } completionHandler:^( BOOL success, NSError *error ) {
                                if ( ! success ) {
                                    NSLog( @"Error occurred while saving image to photo library: %@", error );
                                }
                                
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    // Call UI related operations
                                    [self performSegueWithIdentifier:@"scanCard" sender:[self getRecentPhotoFromCamera]];
                                });
                                
                            }];
                        }
                        else {
                            NSString *temporaryFileName = [NSProcessInfo processInfo].globallyUniqueString;
                            NSString *temporaryFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[temporaryFileName stringByAppendingPathExtension:@"jpg"]];
                            NSURL *temporaryFileURL = [NSURL fileURLWithPath:temporaryFilePath];
                            
                            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                NSError *error = nil;
                                [imageData writeToURL:temporaryFileURL options:NSDataWritingAtomic error:&error];
                                if ( error ) {
                                    NSLog( @"Error occured while writing image data to a temporary file: %@", error );
                                }
                                else {
                                    [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:temporaryFileURL];
                                }
                            } completionHandler:^( BOOL success, NSError *error ) {
                                if ( ! success ) {
                                    NSLog( @"Error occurred while saving image to photo library: %@", error );
                                }
                                
                                // Delete the temporary file.
                                [[NSFileManager defaultManager] removeItemAtURL:temporaryFileURL error:nil];
                                
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    // Call UI related operations
                                    [self performSegueWithIdentifier:@"scanCard" sender:[self getRecentPhotoFromCamera]];
                                });
                            }];
                        }

                        NSLog(@"487 !!!!!!");
                    }
                }];
            }
            else {
                NSLog( @"Could not capture still image: %@", error );
            }
        }];
    } );

    
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"scanCard"]) {
        ((ViewController *)segue.destinationViewController).imageData = sender;
        ((ViewController *)segue.destinationViewController).previousType = TakePhoto;
    }
}

- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer
{
	CGPoint devicePoint = [(AVCaptureVideoPreviewLayer *)self.previewView.layer captureDevicePointOfInterestForPoint:[gestureRecognizer locationInView:gestureRecognizer.view]];
	[self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeAutoExpose atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}

#pragma mark Device Configuration

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
	dispatch_async( self.sessionQueue, ^{
		AVCaptureDevice *device = self.videoDeviceInput.device;
		NSError *error = nil;
		if ( [device lockForConfiguration:&error] ) {
			// Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
			// Call -set(Focus/Exposure)Mode: to apply the new point of interest.
			if ( device.isFocusPointOfInterestSupported && [device isFocusModeSupported:focusMode] ) {
				device.focusPointOfInterest = point;
				device.focusMode = focusMode;
			}

			if ( device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode] ) {
				device.exposurePointOfInterest = point;
				device.exposureMode = exposureMode;
			}

			device.subjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange;
			[device unlockForConfiguration];
		}
		else {
			NSLog( @"Could not lock device for configuration: %@", error );
		}
	} );
}

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
	if ( device.hasFlash && [device isFlashModeSupported:flashMode] ) {
		NSError *error = nil;
		if ( [device lockForConfiguration:&error] ) {
			device.flashMode = flashMode;
			[device unlockForConfiguration];
		}
		else {
			NSLog( @"Could not lock device for configuration: %@", error );
		}
	}
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
	AVCaptureDevice *captureDevice = devices.firstObject;

	for ( AVCaptureDevice *device in devices ) {
		if ( device.position == position ) {
			captureDevice = device;
			break;
		}
	}

	return captureDevice;
}

@end
