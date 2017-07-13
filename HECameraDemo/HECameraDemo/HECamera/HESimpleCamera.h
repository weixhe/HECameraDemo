//
//  HESimpleCamera.h
//  HECameraDemo
//
//  Created by weixhe on 2017/7/11.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

/*!
 *   @brief 调用摄像头的位置：前置摄像头、后置摄像头
 */
typedef NS_ENUM(NSUInteger, HECameraPosition) {
    HECameraPositionRear,       // 后置摄像头
    HECameraPositionFront       // 前置摄像头
};

/*!
 *   @brief 闪光灯的状态
 */
typedef NS_ENUM(NSUInteger, HECameraFlash) {
    HECameraFlashOff,
    HECameraFlashOn,
    HECameraFlashAuto
};

typedef NS_ENUM(NSUInteger, HECameraMirror) {
    HECameraMirrorOff,
    HECameraMirrorOn,
    HECameraMirrorAuto,
};

/*!
 *   @brief 错误码
 */
typedef NS_ENUM(NSUInteger, HECameraErrorCode) {
    HECameraErrorCodeCameraPermission = 10,
    HECameraErrorCodeMicrophonePermission = 11,
    HECameraErrorCodeSession = 12,
    HECameraErrorCodeVideoNotEnabled = 13
};

@interface HESimpleCamera : UIViewController

/*!
 *   @brief 出现错误回调
 */
@property (nonatomic, copy) void (^BlockOnError)(HESimpleCamera *camera, NSError *error);

/*!
 *   @brief 图像的质量 {AVCaptureSessionPresetHigh, AVCaptureSessionPresetLow...}
 */
@property (nonatomic, copy) NSString *quality;

/*!
 *   @brief 使用的摄像头:前置摄像头、后置摄像头
 */
@property (nonatomic, assign) HECameraPosition position;

/*!
 *   @brief 闪光灯的状态：开、关、自动
 */
@property (nonatomic, assign) HECameraFlash flash;

@property (nonatomic, assign) HECameraMirror mirror;

/**
 *  @brief 默认：AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance
 */
@property (nonatomic) AVCaptureWhiteBalanceMode whiteBalanceMode;

/*!
 *   @brief 是否能录像
 */
@property (nonatomic, getter=isVideoEnabled) BOOL videoEnable;

/*!
 *   @brief 是否正在录制视频
 */
@property (nonatomic, getter=isRecording) BOOL recording;

/*!
 *  @brief 是否允许调焦距, 默认：YES
 */
@property (nonatomic, getter=isZoomingEnabled) BOOL zoomingEnabled;

/*!
 *   @brief 最大放大值，调焦距
 */
@property (nonatomic, assign) CGFloat maxScale;

/*!
 *   @brief 是否在抓取图片后固定屏幕的方向
 */
@property (nonatomic, assign) BOOL fixOrientationAfterCapture;

/*!
 *   @brief 是否开启点击聚焦功能，默认：YES
 */
@property (nonatomic, assign) BOOL tapToFocus;

/*!
 *   @brief 是否根据设备的方向自动旋转，默认：YES
 */
@property (nonatomic, assign) BOOL useDeviceOrientation;

#pragma mark - Initialize
/*!
 *   @brief 返回一个HESimpleCamera对象，该对象调用的是后置摄像头，且图像的质量为`高`，用于拍着照片
 */
- (instancetype)init;

/*!
 *   @brief 返回一个HESimpleCamera对象, 默认属性：`AVCaptureSessionPresetHigh` 和 `HECameraPositionRear`
 *   @param videoEnable 是否为录制视频
 */
- (instancetype)initWithVideoEnabled:(BOOL)videoEnable;

/*!
 *   @brief 返回一个HESimpleCamera对象
 *   @param quality     图像的质量 {AVCaptureSessionPresetHigh, AVCaptureSessionPresetLow...}
 *          postion     调用摄像头的位置，分别为前置摄像头和后置摄像头
 *          videoEnable 是否为录制视频
 */
- (instancetype)initWithQuality:(NSString *)quality positon:(HECameraPosition)position videoEnable:(BOOL)videoEnable;

#pragma mark - ViewController
/*!
 *   @brief 将图像显示到目标控制器上
 */
- (void)attachToViewController:(UIViewController *)viewController withFrame:(CGRect)frame;

#pragma mark - Camera

/*!
 *   @brief 开始工作，显示图像
 */
- (void)start;

/*!
 *   @brief 结束工作
 */
- (void)stop;

#pragma mark - Focus
/*!
 *   @brief 添加聚焦框和动画，如果不使用，则使用默认聚焦框
 */
- (void)addFocusBox:(CALayer *)layer animation:(CAAnimation *)animation;

@end


extern NSString * const HESimpleCameraErrorDomain;
