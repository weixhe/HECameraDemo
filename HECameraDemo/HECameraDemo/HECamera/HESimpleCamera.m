//
//  HESimpleCamera.m
//  HECameraDemo
//
//  Created by weixhe on 2017/7/11.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HESimpleCamera.h"
#import "HESimpleCamera+Helper.h"
#import <ImageIO/CGImageProperties.h>
#import "UIImage+FixOrientation.h"

NSString * const HESimpleCameraErrorDomain = @"HESimpleCameraErrorDomain";


@interface HESimpleCamera () <UIGestureRecognizerDelegate
#if __IPHONE_OS_VERSION_MAX_ALLOWED <= __IPHONE_10_0
, AVCapturePhotoCaptureDelegate
#endif
>

#if __IPHONE_OS_VERSION_MAX_ALLOWED <= __IPHONE_10_0  //  __IPHONE_10_0 == 100000
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
#else
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;

#endif

@property (nonatomic, strong) UIView *preView;

@property (nonatomic, strong) AVCaptureSession *session;    // 会话
@property (nonatomic, strong) AVCaptureDevice *videoCaptureDevice;  // 设备
@property (nonatomic, strong) AVCaptureDevice *audioCaptureDevice;
@property (nonatomic, strong) AVCaptureDeviceInput *videoDeviceInput;   // 输入源
@property (nonatomic, strong) AVCaptureDeviceInput *audioDeviceInput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer; // 显示图像的层layer
@property (strong, nonatomic) AVCaptureMovieFileOutput *movieFileOutput;

@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) CALayer *focusBoxLayer;
@property (nonatomic, strong) CAAnimation *focusBoxAnimation;
@property (nonatomic, strong) UIPinchGestureRecognizer *pinchGesture;
@property (nonatomic, assign) CGFloat begingGestureScale;
@property (nonatomic, assign) CGFloat effectiveScale;

@property (nonatomic, copy) void (^BlockOnDidComplete)(HESimpleCamera *camere, NSURL *outputFileUrl, NSError *error);

@end

@implementation HESimpleCamera

- (void)dealloc
{
    [self stop];
}

#pragma mark - Initialize

/*!
 *   @brief 返回一个HESimpleCamera对象，该对象调用的是后置摄像头，且图像的质量为`高`，用于拍着照片
 */
- (instancetype)init {
    return [self initWithVideoEnabled:NO];
}

/*!
 *   @brief 返回一个HESimpleCamera对象, 默认属性：`AVCaptureSessionPresetHigh` 和 `HECameraPositionRear`
 *   @param videoEnable 是否为录制视频
 */
- (instancetype)initWithVideoEnabled:(BOOL)videoEnable {
    return [self initWithQuality:AVCaptureSessionPresetHigh positon:HECameraPositionRear videoEnable:videoEnable];
}

/*!
 *   @brief 返回一个HESimpleCamera对象
 *   @param quality     图像的质量 {AVCaptureSessionPresetHigh, AVCaptureSessionPresetLow...}
 *          postion     调用摄像头的位置，分别为前置摄像头和后置摄像头
 *          videoEnable 是否为录制视频
 */
- (instancetype)initWithQuality:(NSString *)quality positon:(HECameraPosition)position videoEnable:(BOOL)videoEnable {
    if (self = [super init]) {
        [self setupWithQuality:quality position:position videoEnable:videoEnable];
    }
    return self;
}

/// 重写父类方法
- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self setupWithQuality:AVCaptureSessionPresetHigh position:HECameraPositionRear videoEnable:NO];
    }
    return self;
}


- (void)setupWithQuality:(NSString *)quality position:(HECameraPosition)position videoEnable:(BOOL)videoEnable {
    _quality = quality;
    _position = position;
    _videoEnable = videoEnable;
    _fixOrientationAfterCapture = NO;
    _tapToFocus = YES;
    _useDeviceOrientation = NO;
    _flash = HECameraFlashAuto;
    _mirror = HECameraMirrorOff;
    _recording = NO;
    _zoomingEnabled = YES;
//    _maxScale =
    _effectiveScale = 1.0f;

}

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor clearColor];
    
    // 创建显示图像的视图
    self.preView = [[UIView alloc] initWithFrame:CGRectZero];
    self.preView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.preView];
    
    // 创建手势
    // 1. tapGesture
    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onPreViewTapped:)];
    self.tapGesture.numberOfTapsRequired =  1;
    [self.tapGesture setDelaysTouchesEnded:NO];
    [self.preView addGestureRecognizer:self.tapGesture];
    
    // 2. pinch Gesture
    if (self.zoomingEnabled) {
        self.pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(onPinchGesture:)];
        self.pinchGesture.delegate = self;
        [self.preView addGestureRecognizer:self.pinchGesture];
    }
    
    // 添加聚焦框
    [self addDefaultFocusBox];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/*!
 *   @brief 视图重新布局，重置frame和方向
 */
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    self.preView.frame = self.view.bounds;
    self.captureVideoPreviewLayer.frame = self.preView.bounds;
    self.focusBoxLayer.position = CGPointMake(CGRectGetMidX(self.preView.bounds), CGRectGetMidY(self.preView.bounds));
    self.captureVideoPreviewLayer.connection.videoOrientation = [self orientationForConnection];
}

/*!
 *   @brief 返回图像的方向
 */
- (AVCaptureVideoOrientation)orientationForConnection {
    AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationPortrait;
    if (self.useDeviceOrientation) {
        switch ([UIDevice currentDevice].orientation) {
            case UIDeviceOrientationPortrait:
                orientation = AVCaptureVideoOrientationPortrait;
                break;
            case UIDeviceOrientationLandscapeLeft:
                orientation = AVCaptureVideoOrientationLandscapeRight;
                break;
            case UIDeviceOrientationLandscapeRight:
                orientation = AVCaptureVideoOrientationLandscapeLeft;

                break;
            case UIDeviceOrientationPortraitUpsideDown:
                orientation = AVCaptureVideoOrientationPortraitUpsideDown;

                break;
                
            default:
                orientation = AVCaptureVideoOrientationPortrait;
                break;
        }
    } else {
        switch ([UIApplication sharedApplication].statusBarOrientation) {
            case UIInterfaceOrientationLandscapeLeft:
                orientation = AVCaptureVideoOrientationLandscapeLeft;
                break;
            case UIInterfaceOrientationLandscapeRight:
                orientation = AVCaptureVideoOrientationLandscapeRight;
                break;
            case UIInterfaceOrientationPortraitUpsideDown:
                orientation = AVCaptureVideoOrientationPortraitUpsideDown;
                break;
            default:
                orientation = AVCaptureVideoOrientationPortrait;
                break;

        }
    }
    return orientation;
}

//#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
//- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
//    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
//    
//    // layout subviews is not called when rotating from landscape right/left to left/right
//    if (UIInterfaceOrientationIsLandscape([UIDevice currentDevice].orientation) && UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
//        [self.view setNeedsLayout];
//    }
//}
//#else

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // layout subviews is not called when rotating from landscape right/left to left/right
    if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation) && UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
        [self.view setNeedsLayout];
    }
}
//#endif

/*!
 *   @brief 将图像显示到目标控制器上
 */
- (void)attachToViewController:(UIViewController *)viewController withFrame:(CGRect)frame {
    [viewController addChildViewController:self];
    self.view.frame = frame;
    [viewController.view addSubview:self.view];
    [self didMoveToParentViewController:viewController];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


#pragma mark - Gesture Action
/*!
 *   @brief 点击preview的事件响应
 */
- (void)onPreViewTapped:(UIGestureRecognizer *)gesture {
    if (!self.tapToFocus) {
        return;
    }
    
    CGPoint touchedPoint = [gesture locationInView:self.preView];
    CGPoint pointOfInterest = [self convertToPointOfInterestFromViewCoordinates:touchedPoint previewLayer:self.captureVideoPreviewLayer ports:self.videoDeviceInput.ports];
    
    [self focusAtPoint:pointOfInterest];
    [self showFocusBox:touchedPoint];
}

/*!
 *   @brief pinch，放大缩小，调节焦距
 */
- (void)onPinchGesture:(UIPinchGestureRecognizer *)gesture {
    
}

#pragma mark - UIGestureDelegate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
        self.begingGestureScale = self.effectiveScale;
    }
    return YES;
}

#pragma mark - Camera
- (void)initialize {
    if (!_session) {
        _session = [[AVCaptureSession alloc] init];
        if ([_session canSetSessionPreset:self.quality]) {
            _session.sessionPreset = self.quality;      // 设置图像的质量
        }
        // 创建显示图像的layer
        self.captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session];
        self.captureVideoPreviewLayer.bounds = self.preView.bounds;
        self.captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        self.captureVideoPreviewLayer.position = CGPointMake(CGRectGetMidX(self.preView.bounds), CGRectGetMidY(self.preView.bounds));
        [self.preView.layer addSublayer:self.captureVideoPreviewLayer];
        
        // 处理、选择摄像头
        AVCaptureDevicePosition devicePosition;
        switch (self.position) {
            case HECameraPositionRear:      // 后置摄像头
                if ([self isRearCameraAvailable]) {
                    devicePosition = AVCaptureDevicePositionBack;
                } else {
                    devicePosition = AVCaptureDevicePositionFront;
                    _position = HECameraPositionFront;
                }
                break;
            case HECameraPositionFront:     // 前置摄像头
                if ([self isFrontCameraAvalilable]) {
                    devicePosition = AVCaptureDevicePositionFront;
                } else {
                    devicePosition = AVCaptureDevicePositionBack;
                    _position = HECameraPositionRear;
                }
                break;
                
            default:
                break;
        }
        
        if (devicePosition == AVCaptureDevicePositionUnspecified) {
            self.videoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        } else {
            self.videoCaptureDevice = [self cameraWithPosition:devicePosition];
        }
        
        // 输入源
        NSError *error = nil;
        self.videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.videoCaptureDevice error:&error];
        if (!self.videoDeviceInput) {
            [self passError:error];
            return;
        }
        
        if ([self.session canAddInput:self.videoDeviceInput]) {
            [self.session addInput:self.videoDeviceInput];
            self.captureVideoPreviewLayer.connection.videoOrientation = [self orientationForConnection];
        }
        
        // 判断录像，如果可以录像，则需要添加录音功能, 和影响的输出功能
        if (self.videoEnable) {
            self.audioCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            self.audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.audioCaptureDevice error:&error];
            if (!self.audioDeviceInput) {
                [self passError:error];
            }
            
            if ([self.session canAddInput:self.audioDeviceInput]) {
                [self.session addInput:self.audioDeviceInput];
            }
            
            self.movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
            [self.movieFileOutput setMovieFragmentInterval:kCMTimeInvalid];
            if ([self.session canAddOutput:self.movieFileOutput]) {
                [self.session addOutput:self.movieFileOutput];
            }
        }
        
        // 设置自动，不停的调整白平衡
        self.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
#if __IPHONE_OS_VERSION_MAX_ALLOWED <= __IPHONE_10_0
        
        // 图片的输出
        self.photoOutput = [[AVCapturePhotoOutput alloc] init];
        AVCapturePhotoSettings *photoSettings = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey:AVVideoCodecJPEG}];
        [self.photoOutput capturePhotoWithSettings:photoSettings delegate:self];
        if ([self.session canAddOutput:self.photoOutput]) {
            [self.session addOutput:self.photoOutput];
        }
#else
        // 图片的输出
        self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        NSDictionary *outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
        [self.stillImageOutput setOutputSettings:outputSettings];
        
        if ([self.session canAddOutput:self.stillImageOutput]) {
            [self.session addOutput:self.stillImageOutput];
        }
#endif
    }
    
    // 如果connect无效，则重新连接一下
    if (![self.captureVideoPreviewLayer.connection isEnabled]) {
        [self.captureVideoPreviewLayer.connection setEnabled:YES];
    }
    
    // 开始工作
    [self.session startRunning];
}

/*!
 *   @brief 开始工作，显示图像
 */
- (void)start {
    [self requestCameraPermission:^(BOOL granted) {
        if (granted) {
            if (self.videoEnable) {
                [self requestMicrophonePermission:^(BOOL granted) {
                    if (granted) {
                        [self initialize];
                    } else {
                        NSError *error = [NSError errorWithDomain:HESimpleCameraErrorDomain code:HECameraErrorCodeMicrophonePermission userInfo:nil];
                        [self passError:error];
                    }
                }];
            } else {
                [self initialize];
            }
        } else {
            NSError *error = [NSError errorWithDomain:HESimpleCameraErrorDomain code:HECameraErrorCodeCameraPermission userInfo:nil];
            [self passError:error];
        }
    }];
}

/*!
 *   @brief 结束工作
 */
- (void)stop {
    [self.session stopRunning];
    self.session = nil;
}

#pragma mark - Image Capture
/*!
 *   @brief 拍照功能
 *   @param onCapture           拍完照片后的回调
 *          exactedSize         是否为精确的尺寸
 *          animationBlock      动画效果，可以对previewLayer添加自定义的动画
 */
- (void)captureImage:(void (^)(HESimpleCamera *camera, UIImage *image, NSDictionary *metaData, NSError *error))onCapture exactedSize:(BOOL)exactedSize animationBlock:(void (^)(AVCaptureVideoPreviewLayer *previewLayer))animationBlock {
    
    if (!self.session) {
        NSError *error = [NSError errorWithDomain:HESimpleCameraErrorDomain code:HECameraErrorCodeSession userInfo:nil];
        [self passError:error];
        onCapture(self, nil, nil, error);
        return;
    }
    
    AVCaptureConnection *videoConnecton = [self captureConnection];
    videoConnecton.videoOrientation = [self orientationForConnection];
    BOOL flashActive = self.videoCaptureDevice.flashActive;
    if (!flashActive && animationBlock) {
        animationBlock(self.captureVideoPreviewLayer);
    }
    
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnecton completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        
        UIImage *image = nil;
        NSDictionary *metaData = nil;
        
        if (imageDataSampleBuffer != NULL) {
            CGPDFDictionaryRef exifAttachments = CMGetAttachment(imageDataSampleBuffer, kCGImagePropertyExifDictionary, NULL);
            if (exifAttachments) {
                metaData = (__bridge NSDictionary *)exifAttachments;
            }
            
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            image = [UIImage imageWithData:imageData];
            
            if (exactedSize) {
                image = [self cropImage:image usingPreviewLayer:self.captureVideoPreviewLayer];
            }
            
            if (self.fixOrientationAfterCapture) {
                image = [image fixOrientation];
            }
        }
        
        // 结果回调
        if (onCapture) {
            dispatch_async(dispatch_get_main_queue(), ^{
                onCapture(self, image, metaData, nil);
            });
        }
    }];
}

/*!
 *   @brief 拍照功能
 *   @param onCapture           拍完照片后的回调
 *          exactedSize         是否为精确的尺寸
 */
- (void)captureImage:(void (^)(HESimpleCamera *camera, UIImage *image, NSDictionary *metaData, NSError *error))onCapture exactedSize:(BOOL)exactedSize {
    [self captureImage:onCapture exactedSize:exactedSize animationBlock:^(AVCaptureVideoPreviewLayer *previewLayer) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        animation.duration = 0.1;
        animation.autoreverses = YES;
        animation.repeatCount = 0.0;
        animation.fromValue = [NSNumber numberWithFloat:1.0];
        animation.toValue = [NSNumber numberWithFloat:0.1];
        animation.fillMode = kCAFillModeForwards;
        animation.removedOnCompletion = NO;
        [previewLayer addAnimation:animation forKey:@"animateOpacity"];
    }];
}

/*!
 *   @brief 拍照功能
 *   @param onCapture           拍完照片后的回调
 */
- (void)captureImage:(void (^)(HESimpleCamera *camera, UIImage *image, NSDictionary *metaData, NSError *error))onCapture {
    [self captureImage:onCapture exactedSize:NO];

}

#pragma mark - Video Capture


#pragma mark - Focus

/*!
 *   @brief 添加默认的聚焦框
 */
- (void)addDefaultFocusBox {
    CALayer *focusLayer = [CALayer layer];
    focusLayer.cornerRadius = 5.0f;
    focusLayer.bounds = CGRectMake(0, 0, 70, 60);
    focusLayer.borderColor = [UIColor yellowColor].CGColor;
    focusLayer.borderWidth = 1.0f;
    focusLayer.opaque = 0.0f;
    [self.view.layer addSublayer:focusLayer];
    
    CABasicAnimation *focusBoxAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    focusBoxAnimation.duration = 0.75f;
    focusBoxAnimation.autoreverses = NO;
    focusBoxAnimation.repeatCount = 0.0f;
    focusBoxAnimation.fromValue = [NSNumber numberWithFloat:1.0f];
    focusBoxAnimation.toValue = [NSNumber numberWithFloat:0.0f];
    
    [self addFocusBox:focusLayer animation:focusBoxAnimation];
}

/*!
 *   @brief 添加聚焦框和动画，如果不使用，则使用默认聚焦框
 */
- (void)addFocusBox:(CALayer *)layer animation:(CAAnimation *)animation {
    self.focusBoxLayer = layer;
    self.focusBoxAnimation = animation;
}

/*!
 *   @brief 设置聚焦点
 */
- (void)focusAtPoint:(CGPoint)point {
    AVCaptureDevice *device = self.videoCaptureDevice;
    if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.focusMode = AVCaptureFocusModeAutoFocus;
            device.focusPointOfInterest = point;
            [device unlockForConfiguration];
        } else {
            [self passError:error];
        }
    }
}

/*!
 *   @brief 显示聚焦框
 */
- (void)showFocusBox:(CGPoint)point {
    if (self.focusBoxLayer) {
        
        [self.focusBoxLayer removeAllAnimations];
        
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        self.focusBoxLayer.position = point;
        [CATransaction commit];
        
        if (self.focusBoxAnimation) {
            [self.focusBoxLayer addAnimation:self.focusBoxAnimation forKey:@"animateOpacity"];
        }
    }
    
}

#pragma mark - Class Method

#pragma mark - Helpers

/*!
 *   @brief 是否支持闪光灯
 */
- (BOOL)isFlashAvailable {
    return self.videoCaptureDevice.hasFlash && self.videoCaptureDevice.isFlashAvailable;
}

/*!
 *   @brief 是否支持手电筒
 */
- (BOOL)isTorchAvailable {
    return self.videoCaptureDevice.hasTorch && self.videoCaptureDevice.isTorchAvailable;

}

/*!
 *   @brief 设置闪光灯的模式，分为三种{HECameraFlashOff， HECameraFlashOn, HECameraFlashAuto}
 */
- (BOOL)setFlashMode:(HECameraFlash)cameraFlash {
    if (!self.session) {
        return NO;
    }
    
    AVCaptureFlashMode flashMode;
    switch (cameraFlash) {
        case HECameraFlashOn:
            flashMode = AVCaptureFlashModeOn;
            break;
        case HECameraFlashOff:
            flashMode = AVCaptureFlashModeOff;
            break;
        case HECameraFlashAuto:
            flashMode = AVCaptureFlashModeAuto;
            break;
            
        default:
            flashMode = AVCaptureFlashModeAuto;
            break;
    }
    
    if ([self.videoCaptureDevice isFlashModeSupported:flashMode]) {
        NSError *error;
        if ([self.videoCaptureDevice lockForConfiguration:&error]) {
            self.videoCaptureDevice.flashMode = flashMode;
            [self.videoCaptureDevice unlockForConfiguration];
            _flash = cameraFlash;
            return YES;
        } else {
            [self passError:error];
            return NO;
        }
    }
    return NO;
}

/*!
 *   @brief 设置白平衡
 */
- (void)setWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode {
    if ([self.videoCaptureDevice isWhiteBalanceModeSupported:whiteBalanceMode]) {
        NSError *error;
        if ([self.videoCaptureDevice lockForConfiguration:&error]) {
            [self.videoCaptureDevice setWhiteBalanceMode:whiteBalanceMode];
            [self.videoCaptureDevice unlockForConfiguration];
            
            _whiteBalanceMode = whiteBalanceMode;
        } else {
            [self passError:error];
        }
    }
}

/*!
 *   @brief 设置视频镜像
 */
- (void)setMirror:(HECameraMirror)mirror {
    _mirror = mirror;
    
    if (!self.session) {
        return;
    }
    
    AVCaptureConnection *videoConnection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
#if __IPHONE_OS_VERSION_MAX_ALLOWED <= __IPHONE_10_0
    AVCaptureConnection *pictureConnection = [self.photoOutput connectionWithMediaType:AVMediaTypeVideo];
#else
    AVCaptureConnection *pictureConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
#endif
    switch (mirror) {
        case HECameraMirrorOn: {
            if ([videoConnection isVideoMirroringSupported]) {
                [videoConnection setVideoMirrored:YES];
            }
            if ([pictureConnection isVideoMirroringSupported]) {
                [pictureConnection setVideoMirrored:YES];
            }
            
            break;
        }
        case HECameraMirrorOff: {
            if ([videoConnection isVideoMirroringSupported]) {
                [videoConnection setVideoMirrored:NO];
            }
            if ([pictureConnection isVideoMirroringSupported]) {
                [pictureConnection setVideoMirrored:NO];
            }

            break;
        }
        case HECameraMirrorAuto: {
            BOOL shouldMirror = (self.position == HECameraPositionFront);
            if ([videoConnection isVideoMirroringSupported]) {
                [videoConnection setVideoMirrored:shouldMirror];
            }
            if ([pictureConnection isVideoMirroringSupported]) {
                [pictureConnection setVideoMirrored:shouldMirror];
            }
            break;
        }
        default:
            break;
    }
}

/*!
 *   @brief 切换前后摄像头位置，并返回当前使用的哪个摄像头
 */
- (HECameraPosition)togglePosition {
    
    if (!self.session) {
        return self.position;
    }
    
    if (self.position == HECameraPositionFront) {
        [self setCameraPosition:HECameraPositionFront];
    } else {
        [self setCameraPosition:HECameraPositionRear];
    }
    return _position;
}

/*!
 *   @brief 设置摄像头
 */
- (void)setCameraPosition:(HECameraPosition)cameraPosition {
    if (self.position == cameraPosition || !self.session) {
        return;
    }
    
    if (cameraPosition == HECameraPositionRear && ![self isRearCameraAvailable]) {
        return;
    }
    if (cameraPosition == HECameraPositionFront && ![self isFrontCameraAvalilable]) {
        return;
    }
    
    [self.session beginConfiguration];
    
    // 移除输入源
    [self.session removeInput:self.videoDeviceInput];
    
    // 添加新的输入源
    AVCaptureDevice *device = nil;
    if (self.videoDeviceInput.device.position == AVCaptureDevicePositionBack) {
        device = [self cameraWithPosition:AVCaptureDevicePositionFront];
    } else {
        device = [self cameraWithPosition:AVCaptureDevicePositionBack];
    }
    
    if (!device) {
        return;
    }
    
    NSError *error = nil;
    AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if (error) {
        [self passError:error];
        [self.session commitConfiguration];
        return;
    }
    if ([self.session canAddInput:videoInput]) {
        [self.session addInput:videoInput];
        [self.session commitConfiguration];
    }
    
    self.position = cameraPosition;
    [self setMirror:self.mirror];
}

/*!
 *   @brief 根据选择的摄像头位置，选择出相应的device设备，如果找不到设备中没有摄像头，则返回nil
 */
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

/*!
 *   @brief 返回静态图片的连接connect
 */
- (AVCaptureConnection *)captureConnection {
    AVCaptureConnection *videoConnection = nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED <= __IPHONE_10_0
    for (AVCaptureConnection *connection in self.photoOutput.connections) {
#else
    for (AVCaptureConnection *connection in self.stillImageOutput.connections) {
#endif
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqualToString:AVMediaTypeVideo]) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) {
            break;
        }
    }
    return videoConnection;
}

/*!
 *   @brief 设置属性：videoCaptureDevice， 同时设置device的闪光灯效果
 */
- (void)setVideoCaptureDevice:(AVCaptureDevice *)videoCaptureDevice {
    _videoCaptureDevice = videoCaptureDevice;
    
    if (videoCaptureDevice.flashMode == AVCaptureFlashModeOn) {
        _flash = HECameraFlashOn;
    } else if (videoCaptureDevice.flashMode == AVCaptureFlashModeOff) {
        _flash = HECameraFlashOff;
    } else if (videoCaptureDevice.flashMode == AVCaptureFlashModeAuto) {
        _flash = HECameraFlashAuto;
    } else {
        _flash = HECameraFlashOff;
    }
    
    self.effectiveScale = 1.0f;
    
    if (self.BlockOnDeviceChange) {
        __weak typeof(self) weakSelf = self;
        self.BlockOnDeviceChange(weakSelf, videoCaptureDevice);
    }
}

/*!
 *   @brief 是否支持后置摄像头
 */
- (BOOL)isRearCameraAvailable {
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear];
}

/*!
 *   @brief 是否支持前置摄像头
 */
- (BOOL)isFrontCameraAvalilable {
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront];
}


/*!
 *   @brief 请求使用摄像头录像的权限
 */
- (void)requestCameraPermission:(void (^)(BOOL granted))complete {
    if ([AVCaptureDevice respondsToSelector:@selector(requestAccessForMediaType: completionHandler:)]) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            // return to main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                if(complete) {
                    complete(granted);
                }
            });
        }];
    } else {
        if(complete) {
            complete(NO);
        }
    }
}

/*!
 *   @brief 请求使用麦克风的权限
 */
- (void)requestMicrophonePermission:(void  (^)(BOOL granted))complete {
    if ([[AVAudioSession sharedInstance] respondsToSelector:@selector(requestRecordPermission:)]) {
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (complete) {
                    complete(granted);
                }
            });
        }];
    } else {
        if(complete) {
            complete(NO);
        }
    }
}

- (void)passError:(NSError *)error {
    if (self.BlockOnError) {
        __weak typeof(self) weakSelf = self;
        self.BlockOnError(weakSelf, error);
    }
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED <= __IPHONE_10_0

#pragma mark -  AVCapturePhotoCaptureDelegate

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput willBeginCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings {
    
}


- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput willCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings {
    
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings {
    
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishProcessingPhotoSampleBuffer:(nullable CMSampleBufferRef)photoSampleBuffer previewPhotoSampleBuffer:(nullable CMSampleBufferRef)previewPhotoSampleBuffer resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings bracketSettings:(nullable AVCaptureBracketedStillImageSettings *)bracketSettings error:(nullable NSError *)error {
    
}


- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishProcessingRawPhotoSampleBuffer:(nullable CMSampleBufferRef)rawSampleBuffer previewPhotoSampleBuffer:(nullable CMSampleBufferRef)previewPhotoSampleBuffer resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings bracketSettings:(nullable AVCaptureBracketedStillImageSettings *)bracketSettings error:(nullable NSError *)error {
    
}


- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishRecordingLivePhotoMovieForEventualFileAtURL:(NSURL *)outputFileURL resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings {
    
}


- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishProcessingLivePhotoToMovieFileAtURL:(NSURL *)outputFileURL duration:(CMTime)duration photoDisplayTime:(CMTime)photoDisplayTime resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings error:(nullable NSError *)error {
    
}


- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings error:(nullable NSError *)error {
    
}

#endif

@end
