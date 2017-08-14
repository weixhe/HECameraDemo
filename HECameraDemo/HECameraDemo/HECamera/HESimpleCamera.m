//
//  HESimpleCamera.m
//  HECameraDemo
//
//  Created by weixhe on 2017/7/11.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HESimpleCamera.h"
#import "HECameraConstant.h"
#import "HESimpleCamera+Helper.h"
#import <ImageIO/CGImageProperties.h>
#import "UIImage+FixOrientation.h"
#import "HERecordEncoder.h"
#import <Photos/Photos.h>

NSString * const HESimpleCameraErrorDomain = @"HESimpleCameraErrorDomain";
char * queueName = "com.weixhe.im.camera.video.queue";


@interface HESimpleCamera () <UIGestureRecognizerDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate
#if SDK_Above_10_0
, AVCapturePhotoCaptureDelegate
#endif
>
{
    CMTime _timeOffset;     // 录制的偏移CMTime, 当有暂停时起作用
    CMTime _lastVideo;      // 记录上一次视频数据文件的CMTime
    CMTime _lastAudio;      // 记录上一次音频数据文件的CMTime
    BOOL _interrupt;        // 是否被的打断，对应‘暂停’时刻
    size_t _videoSize;
    
    NSInteger _cx;      // 视频分辨的宽
    NSInteger _cy;      // 视频分辨的高
    int _channels;      // 音频通道
    Float64 _samplerate;    // 音频采样率
}

#if SDK_Above_10_0  //  __IPHONE_10_0 == 100000
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, strong) AVCapturePhotoSettings *photoSettings;
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
//@property (strong, nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioDataOutput;
@property (nonatomic, strong) dispatch_queue_t videoQueue;
@property (nonatomic, strong) HERecordEncoder *encoder;
@property (atomic, assign) CMTime startTime;// 开始录制的时间
@property (atomic, assign) CGFloat currentRecordTime;// 当前录制时间
@property (atomic, assign) CGFloat maxRecordTime;// 录制最长时间
@property (nonatomic, copy) NSString * videoPath;       // 保存video的路径


@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) CALayer *focusBoxLayer;
@property (nonatomic, strong) CAAnimation *focusBoxAnimation;
@property (nonatomic, strong) UIPinchGestureRecognizer *pinchGesture;
@property (nonatomic, assign) CGFloat beginGestureScale;
@property (nonatomic, assign) CGFloat effectiveScale;

@property (nonatomic, copy) void (^BlockOnProgressing)(HESimpleCamera *camere, CGFloat time);
@property (nonatomic, copy) void (^BlockOnDidCaptured)(HESimpleCamera *camera, UIImage *image, NSDictionary *metaData, NSError *error);
@property (nonatomic, assign) BOOL exactedSize;

@end

@implementation HESimpleCamera

- (void)dealloc
{
    [self stopSession];
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
    _torch = HECameraTorchAuto;
    _mirror = HECameraMirrorOff;
    _recording = NO;
    _zoomingEnabled = YES;
//    _maxScale =
    _effectiveScale = 1.0f;
    
#if SDK_Above_10_0
    _photoSettings = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey:AVVideoCodecJPEG}];
#endif

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
    [self touchPoint:[gesture locationInView:self.preView]];
}

- (void)touchPoint:(CGPoint)point {
    CGPoint pointOfInterest = [self convertToPointOfInterestFromViewCoordinates:point previewLayer:self.captureVideoPreviewLayer ports:self.videoDeviceInput.ports];
    
    [self focusAtPoint:pointOfInterest];
    [self showFocusBox:point];

}

/*!
 *   @brief pinch，放大缩小，调节焦距
 */
- (void)onPinchGesture:(UIPinchGestureRecognizer *)gesture {
    
    BOOL allTouchesAreOnThePreviewLayer = YES;
    NSUInteger numTouches = [gesture numberOfTouches], i = 0;
    
    for (i = 0; i < numTouches; ++i ) {
        CGPoint location = [gesture locationOfTouch:i inView:self.preView];
        CGPoint convertedLocation = [self.preView.layer convertPoint:location fromLayer:self.view.layer];
        if (![self.preView.layer containsPoint:convertedLocation]) {
            allTouchesAreOnThePreviewLayer = NO;
            break;
        }
    }
    
    if (allTouchesAreOnThePreviewLayer) {
        
        _effectiveScale = _beginGestureScale * gesture.scale;
        if (_effectiveScale < 1.0f) {
            _effectiveScale = 1.0f;
        }
        
        if (_effectiveScale > self.videoCaptureDevice.activeFormat.videoMaxZoomFactor) {
            _effectiveScale = self.videoCaptureDevice.activeFormat.videoMaxZoomFactor;
        }
        
        NSError *error = nil;
        if ([self.videoCaptureDevice lockForConfiguration:&error]) {
            [self.videoCaptureDevice rampToVideoZoomFactor:_effectiveScale withRate:10];
            [self.videoCaptureDevice unlockForConfiguration];
        } else {
            [self passError:error];
        }
    }
}

#pragma mark - UIGestureDelegate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
        self.beginGestureScale = self.effectiveScale;
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
            _position = HECameraPositionRear;   // 因为有初始化值，所以这里的几乎不会走
            self.videoCaptureDevice = [self cameraWithPosition:AVCaptureDevicePositionBack];
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
        
        // 判断录像，如果可以录像，则需要添加录音功能, 和影像的输出功能
        if (self.videoEnable) {
            self.audioCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            self.audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.audioCaptureDevice error:&error];
            if (!self.audioDeviceInput) {
                [self passError:error];
            }
            
            if ([self.session canAddInput:self.audioDeviceInput]) {
                [self.session addInput:self.audioDeviceInput];
            }
            
            self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
            self.audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
            
            if ([self.session canAddOutput:self.videoDataOutput]) {
                [self.session addOutput:self.videoDataOutput];
            }
            if ([self.session canAddOutput:self.audioDataOutput]) {
                [self.session addOutput:self.audioDataOutput];
            }
            
            // 初始化video的配置
            self.videoDataOutput.videoSettings = [self setDefaultVideoSettings];
            self.videoQueue = dispatch_queue_create(queueName, DISPATCH_QUEUE_SERIAL);
            [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoQueue];
            [self.audioDataOutput setSampleBufferDelegate:self queue:self.videoQueue];
            // 设置视频的分辨率
            _cx = 720;
            _cy = 1280;
            _maxRecordTime = 60.0f;  // 最多录制默认60s
        }
        
        // 设置自动，不停的调整白平衡
        self.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
#if SDK_Above_10_0
        // 图片的输出， 预先设置一些属性
        self.photoOutput = [[AVCapturePhotoOutput alloc] init];
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
- (void)startSession {
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
- (void)stopSession {
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
    
    self.BlockOnDidCaptured = onCapture;
    self.exactedSize = exactedSize;
    
#if SDK_Above_10_0
    [self.photoOutput capturePhotoWithSettings:[AVCapturePhotoSettings photoSettingsFromPhotoSettings:self.photoSettings] delegate:self];
#else
    __weak typeof(self) weakSelf = self;
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnecton completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        
        if (error) {
            [weakSelf passError:error];
            self.BlockOnDidCaptured(weakSelf, nil, nil, error);
            return;
        }
        [weakSelf handleCaptureWithPhotoSampleBuffer:imageDataSampleBuffer previewPhotoSampleBuffer:imageDataSampleBuffer];
    }];
#endif
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
/*!
 *   @brief 开始录制视频，传入目的地址，和回调的block
 */
- (void)startRecordingWithOutputPath:(NSString *)path progress:(void (^)(HESimpleCamera *camera, CGFloat time))progress {
    // check if video is enabled
    if (!self.videoEnable) {
        NSError *error = [NSError errorWithDomain:HESimpleCameraErrorDomain code:HECameraErrorCodeVideoNotEnabled userInfo:nil];
        [self passError:error];
        return;
    }
    
    [self setTorchMode:self.torch];

    if (!_recording) {
        _videoPath = path;
        _BlockOnProgressing = progress;
        _recording = YES;
        _paused = NO;
        _encoder = nil;
        _startTime = CMTimeMake(0, 0);
        _currentRecordTime = 0;
        _videoSize = 0;
        
        AVCaptureConnection *connection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
        connection.videoOrientation = [self orientationForConnection];
    }
}

/*!
 *   @brief 暂停录制
 */
- (void)pauseRecording {
    if(!self.videoEnable) {
        return;
    }
    if (_recording) {
        _paused = YES;
        _interrupt = YES;
    }
}

/*!
 *   @brief 继续录制
 */
- (void)resumeRecording {
    if(!self.videoEnable) {
        return;
    }
    if (_paused) {
        _paused = NO;
    }
}

/*!
 *   @brief 停止录制, block返回第一针的图片
 */
- (void)stopRecording:(void (^)(UIImage *thumb, NSString *outputPath))handler {
    if(!self.videoEnable) {
        return;
    }
    
    @synchronized(self) {
        if (_recording) {
            NSString *path = self.videoPath;
            NSURL *url = [NSURL fileURLWithPath:path];
            _recording = NO;
            dispatch_async(self.videoQueue, ^{
                [self.encoder finishWithCompletionHandler:^{
                    _recording = NO;
                    _paused = NO;
                    _encoder = nil;
                    _startTime = CMTimeMake(0, 0);
                    _currentRecordTime = 0;
                    _videoSize = 0;
                    if (self.BlockOnProgressing) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __weak typeof(self) weakSelf = self;
                            self.BlockOnProgressing(weakSelf, weakSelf.currentRecordTime);
                        });
                    }
                    if (self.autoSaveToPhotoAlbum) {
                        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
                        } completionHandler:^(BOOL success, NSError * _Nullable error) {
                            HELog(@"保存成功");
                        }];
                    }
                    [self movieToFirstImageHandler:handler];
                }];
            });
        }
    }
}

/*!
 *   @brief 默认的video的配置
 */
- (NSDictionary *)setDefaultVideoSettings {
    NSDictionary *defaultSetting = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    return defaultSetting;
}

/*!
 *   @brief 设置音频格式
 */
- (void)setAudioFormat:(CMFormatDescriptionRef)fmt {
    const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt);
    _samplerate = asbd->mSampleRate;
    _channels = asbd->mChannelsPerFrame;
}

// 调整媒体数据的时间
- (CMSampleBufferRef)adjustTime:(CMSampleBufferRef)sample by:(CMTime)offset {
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    for (CMItemCount i = 0; i < count; i++) {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
    }
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
    free(pInfo);
    return sout;
}

/*!
 *   @brief 获取视频第一帧的图片
 */
- (void)movieToFirstImageHandler:(void (^)(UIImage *thumb, NSString *outputPath))handler {
    NSURL *url = [NSURL fileURLWithPath:self.videoPath];
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.appliesPreferredTrackTransform = TRUE;
    CMTime thumbTime = CMTimeMakeWithSeconds(0, 60);
    generator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
    AVAssetImageGeneratorCompletionHandler generatorHandler =
    ^(CMTime requestedTime, CGImageRef im, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error){
        if (result == AVAssetImageGeneratorSucceeded) {
            UIImage *thumbImg = [UIImage imageWithCGImage:im];
            if (handler) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(thumbImg, self.videoPath);
                });
            }
        }
    };
    [generator generateCGImagesAsynchronouslyForTimes:
    [NSArray arrayWithObject:[NSValue valueWithCMTime:thumbTime]] completionHandler:generatorHandler];
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
    focusLayer.opacity = 0.0f;
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
    NSError *error;
    if ([device lockForConfiguration:&error]) {
        if ([device isFocusPointOfInterestSupported]) {     // 设定聚焦点
            device.focusPointOfInterest = point;
        }
        if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {    // 设定聚焦模式
            device.focusMode = AVCaptureFocusModeAutoFocus;
        }
        
        if ([device isExposurePointOfInterestSupported]) {      // 设定曝光点
            device.exposurePointOfInterest = point;
        }
        if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) { // 设定曝光模式
            device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        }
    } else {
        [self passError:error];
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
    if (!self.session || cameraFlash == _flash) {
        return NO;
    }
    
    if (![self isFlashAvailable]) {
        [self passError:[NSError errorWithDomain:HESimpleCameraErrorDomain code:HECameraErrorCodeNotAvaliableFlash userInfo:nil]];
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
#if SDK_Above_10_0
    
    if ([[self.photoOutput supportedFlashModes] containsObject:@(flashMode)]) {
        self.photoSettings.flashMode = flashMode;
        self.photoOutput.photoSettingsForSceneMonitoring = self.photoSettings;
        _flash = cameraFlash;
        return YES;
    }
    
#else
    
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
#endif
    return NO;
}

/*!
 *   @brief 设置手电筒的状态
 */
- (BOOL)setTorchMode:(HECameraTorch)torchMode {
    if (!self.session) {
        return NO;
    }
    
    if (![self isTorchAvailable]) {
        [self passError:[NSError errorWithDomain:HESimpleCameraErrorDomain code:HECameraErrorCodeNotAvaliableTorch userInfo:nil]];
        return NO;
    }
    
    AVCaptureTorchMode torch;
    switch (torchMode) {
        case HECameraTorchOn:
            torch = AVCaptureTorchModeOn;
            break;
        case HECameraTorchOff:
            torch = AVCaptureTorchModeOff;
            break;
        case HECameraTorchAuto:
            torch = AVCaptureTorchModeAuto;
            break;
            
        default:
            torch = AVCaptureTorchModeAuto;
            break;
    }

    if ([self.videoCaptureDevice isTorchModeSupported:torch]) {
        NSError *error;
        if ([self.videoCaptureDevice lockForConfiguration:&error]) {
            self.videoCaptureDevice.torchMode = torch;
            [self.videoCaptureDevice unlockForConfiguration];
            _torch = torchMode;
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
    if (self.isVideoEnabled) {
        AVCaptureConnection *videoConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
//        [self.audioDataOutput connectionWithMediaType:AVMediaTypeAudio];
        switch (mirror) {
            case HECameraMirrorOn: {
                if ([videoConnection isVideoMirroringSupported]) {
                    [videoConnection setVideoMirrored:YES];
                }

                break;
            }
            case HECameraMirrorOff: {
                if ([videoConnection isVideoMirroringSupported]) {
                    [videoConnection setVideoMirrored:NO];
                }
                
                break;
            }
            case HECameraMirrorAuto: {
                BOOL shouldMirror = (self.position == HECameraPositionFront);
                if ([videoConnection isVideoMirroringSupported]) {
                    [videoConnection setVideoMirrored:shouldMirror];
                }
                break;
            }
            default:
                break;
        }
    } else {
        
#if SDK_Above_10_0
        AVCaptureConnection *pictureConnection = [self.photoOutput connectionWithMediaType:AVMediaTypeVideo];
#else
        AVCaptureConnection *pictureConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
#endif
        switch (mirror) {
            case HECameraMirrorOn: {
                if ([pictureConnection isVideoMirroringSupported]) {
                    [pictureConnection setVideoMirrored:YES];
                }
                
                break;
            }
            case HECameraMirrorOff: {
                if ([pictureConnection isVideoMirroringSupported]) {
                    [pictureConnection setVideoMirrored:NO];
                }
                
                break;
            }
            case HECameraMirrorAuto: {
                BOOL shouldMirror = (self.position == HECameraPositionFront);
                if ([pictureConnection isVideoMirroringSupported]) {
                    [pictureConnection setVideoMirrored:shouldMirror];
                }
                break;
            }
            default:
                break;
        }
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
        [self setCameraPosition:HECameraPositionRear];
    } else {
        [self setCameraPosition:HECameraPositionFront];
    }
    [self changeCameraAnimation];
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
        self.videoDeviceInput = videoInput;
        [self.session addInput:videoInput];
        [self.session commitConfiguration];
    }
    
    _position = cameraPosition;
    [self setMirror:self.mirror];
}

/*!
 *   @brief 调节感光度, ISO取值范围0.0~1.0
 */
- (void)setCameraISO:(CGFloat)ISO {
    ISO = MAX(ISO, 0.0);
    ISO = MIN(ISO, 1.0);
    CGFloat currentISO = (self.videoCaptureDevice.activeFormat.maxISO - self.videoCaptureDevice.activeFormat.minISO) * ISO + self.videoCaptureDevice.activeFormat.minISO;
    NSError *error = nil;
    if ([self.videoDeviceInput.device lockForConfiguration:&error]) {
        
        [self.videoCaptureDevice setExposureModeCustomWithDuration:AVCaptureExposureDurationCurrent ISO:currentISO completionHandler:nil];
        [self.videoCaptureDevice unlockForConfiguration];
        _ISO = ISO;
    } else {
        [self passError:error];
    }
}


/*!
 *   @brief 根据选择的摄像头位置，选择出相应的device设备，如果找不到设备中没有摄像头，则返回nil
 */
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
#if SDK_Above_10_0
    AVCaptureDeviceDiscoverySession *discoverSession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position];
    NSArray *devices = discoverSession.devices;
#else
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
#endif
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
#if SDK_Above_10_0
    for (AVCaptureConnection *connection in self.photoOutput.connections) {
#else
    for (AVCaptureConnection *connection in self.stillImageOutput.connections) {
#endif
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqualToString:AVMediaTypeVideo]) {
                videoConnection = connection;
                
                // 防抖模式
                if ([videoConnection isVideoStabilizationSupported] && videoConnection .preferredVideoStabilizationMode != AVCaptureVideoStabilizationModeAuto) {
                    videoConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
                }
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
    
#if SDK_Above_10_0
    self.photoSettings.flashMode = _flash == HECameraFlashOn ? AVCaptureFlashModeOn : (_flash == AVCaptureFlashModeAuto ? AVCaptureFlashModeAuto : AVCaptureFlashModeOff);
#else
    videoCaptureDevice.flashMode = _flash == HECameraFlashOn ? AVCaptureFlashModeOn : _flash == AVCaptureFlashModeAuto ? AVCaptureFlashModeAuto : AVCaptureFlashModeOff;
#endif
    self.effectiveScale = 1.0f;
    _ISO = (videoCaptureDevice.ISO - self.videoCaptureDevice.activeFormat.minISO) / (self.videoCaptureDevice.activeFormat.maxISO - self.videoCaptureDevice.activeFormat.minISO);

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
 
/*!
 *   @brief 处理拍照结果，将数据转换成UIImage对象，并调用block回调
 */
- (void)handleCaptureWithPhotoSampleBuffer:(nullable CMSampleBufferRef)photoSampleBuffer previewPhotoSampleBuffer:(nullable CMSampleBufferRef)previewPhotoSampleBuffer {
    UIImage *image = nil;
    NSDictionary *metaData = nil;
    
    if (photoSampleBuffer != NULL) {
        CFTypeRef/*CGPDFDictionaryRef*/ exifAttachments = CMGetAttachment(photoSampleBuffer, kCGImagePropertyExifDictionary, NULL);
        if (exifAttachments) {
            metaData = (__bridge NSDictionary *)exifAttachments;
        }
#if SDK_Above_10_0
        NSData *data = [AVCapturePhotoOutput JPEGPhotoDataRepresentationForJPEGSampleBuffer:photoSampleBuffer previewPhotoSampleBuffer:previewPhotoSampleBuffer];
        image = [UIImage imageWithData:data];
#else
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:photoSampleBuffer];
        image = [UIImage imageWithData:imageData];
#endif
        if (self.exactedSize) {
            image = [self cropImage:image usingPreviewLayer:self.captureVideoPreviewLayer];
        }
        
        if (self.fixOrientationAfterCapture) {
            image = [image fixOrientation];
        }
    }
    
    // 结果回调
    if (self.BlockOnDidCaptured) {
        
        if ([NSThread isMainThread]) {
            __weak typeof(self) weakSelf = self;
            self.BlockOnDidCaptured(weakSelf, image, metaData, nil);
        } else {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                __weak typeof(self) weakSelf = self;
                self.BlockOnDidCaptured(weakSelf, image, metaData, nil);
            });
        }
    }
}
    
#pragma mark - 切换动画
- (void)changeCameraAnimation {
    CATransition *changeAnimation = [CATransition animation];
//        changeAnimation.delegate = self;
    changeAnimation.duration = 0.45;
    changeAnimation.type = @"oglFlip";
    changeAnimation.subtype = kCATransitionFromRight;
    changeAnimation.timingFunction = UIViewAnimationCurveEaseInOut;
    [self.preView.layer addAnimation:changeAnimation forKey:@"changeAnimation"];
}
    
 

#if SDK_Above_10_0

#pragma mark -  AVCapturePhotoCaptureDelegate

/*!
 *   @brief 取出拍照的照片（已被处理过的图片）
 */
- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishProcessingPhotoSampleBuffer:(nullable CMSampleBufferRef)photoSampleBuffer previewPhotoSampleBuffer:(nullable CMSampleBufferRef)previewPhotoSampleBuffer resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings bracketSettings:(nullable AVCaptureBracketedStillImageSettings *)bracketSettings error:(nullable NSError *)error {
    
    if (error) {
        [self passError:error];
        __weak typeof(self) weakSelf = self;
        self.BlockOnDidCaptured(weakSelf, nil, nil, error);
        return;
    }

    [self handleCaptureWithPhotoSampleBuffer:photoSampleBuffer previewPhotoSampleBuffer:previewPhotoSampleBuffer];
}

#endif
    
#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {

    BOOL isVideo = YES;     // 用来区分是录音还是录像

    @synchronized (self) {
        if (!self.recording || self.paused) {
            return;
        }
        if (captureOutput != self.videoDataOutput) {
            isVideo = NO;
        }
        // 初始化编码器，当有音频和视频参数时创建编码器
        if ((self.encoder == nil) && !isVideo) {
            CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(sampleBuffer);
            [self setAudioFormat:fmt];
            self.videoPath = self.videoPath ?: [GetFilePath() stringByAppendingPathComponent:GetFileName()];
            self.encoder = [HERecordEncoder encoderWithPath:self.videoPath width:_cx height:_cy channels:_channels rate:_samplerate];
        }
        
        // 判断是否中断录制过
        if (_interrupt) {
            if (isVideo) {
                return;
            }
            _interrupt = NO;
            
            
            // 计算暂停的时间
            CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            CMTime last = isVideo ? _lastVideo : _lastAudio;
            if (last.flags & kCMTimeFlags_Valid) {
                if (_timeOffset.flags & kCMTimeFlags_Valid) {
                    pts = CMTimeSubtract(pts, _timeOffset);
                }
                CMTime offset = CMTimeSubtract(pts, last);
                if (_timeOffset.value == 0) {
                    _timeOffset = offset;
                } else {
                    _timeOffset = CMTimeAdd(_timeOffset, offset);
                }
            }
            _lastVideo.flags = 0;
            _lastAudio.flags = 0;
        }
        // 增加sampleBuffer的引用计时, 这样我们可以释放这个或修改这个数据，防止在修改时被释放
        CFRetain(sampleBuffer);
        if (_timeOffset.value > 0) {
            CFRelease(sampleBuffer);
            // 根据得到的timeOffset调整
            sampleBuffer = [self adjustTime:sampleBuffer by:_timeOffset];
        }
        // 记录暂停上一次录制的时间
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CMTime dur = CMSampleBufferGetDuration(sampleBuffer);
        if (dur.value > 0) {
            pts = CMTimeAdd(pts, dur);
        }
        if (isVideo) {
            _lastVideo = pts;
        } else {
            _lastAudio = pts;
        }
    }
    CMTime dur = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    if (self.startTime.value == 0) {
        self.startTime = dur;
    }
    CMTime sub = CMTimeSubtract(dur, self.startTime);
    self.currentRecordTime = CMTimeGetSeconds(sub);
    if (self.currentRecordTime > self.maxRecordTime) {
        if (self.currentRecordTime - self.maxRecordTime < 0.1) {
            
            if (self.BlockOnProgressing) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __weak typeof(self) weakSelf = self;
                    weakSelf.BlockOnProgressing(weakSelf, weakSelf.maxRecordTime);
                });
            }
        }
        return;
    }
    if (self.BlockOnProgressing) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __weak typeof(self) weakSelf = self;
            weakSelf.BlockOnProgressing(weakSelf, weakSelf.currentRecordTime);
        });
    }
    
    _videoSize += CMSampleBufferGetTotalSampleSize(sampleBuffer);
    // 进行数据编码
    [self.encoder encodeFrame:sampleBuffer isVideo:isVideo];
    CFRelease(sampleBuffer);
    
}
    
@end
