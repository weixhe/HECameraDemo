//
//  HESimpleCamera.m
//  HECameraDemo
//
//  Created by weixhe on 2017/7/11.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HESimpleCamera.h"
#import "HESimpleCamera+Helper.h"

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
