//
//  HESimpleCamera.m
//  HECameraDemo
//
//  Created by weixhe on 2017/7/11.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HESimpleCamera.h"

NSString *const HESimpleCameraErrorDomain = @"HESimpleCameraErrorDomain";


@interface HESimpleCamera ()

#if __IPHONE_OS_VERSION_MAX_ALLOWED <= __IPHONE_10_0  //  __IPHONE_10_0 == 100000
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
#else
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;

#endif

@property (nonatomic, strong) AVCaptureSession *session;    // 会话
@property (nonatomic, strong) AVCaptureDevice *videoCaptureDevice;  // 设备
@property (nonatomic, strong) AVCaptureDevice *audioCaptureDevice;
@property (nonatomic, strong) AVCaptureDeviceInput *videoDeviceInput;   // 输入源
@property (nonatomic, strong) AVCaptureDeviceInput *audioDeviceInput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer; // 显示图像的层layer

@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) CALayer *focusBoxLayer;
@property (nonatomic, strong) CAAnimation *focusBoxAnimation;
@property (nonatomic, strong) UIPinchGestureRecognizer *pinchGesture;
@property (nonatomic, assign) CGFloat begingGestureScale;
@property (nonatomic, assign) CGFloat effectiveScale;

@property (nonatomic, copy) void (^BlockOnDidComplete)(HESimpleCamera *camere, NSURL *outputFileUrl, NSError *error);

@end

@implementation HESimpleCamera

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

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
