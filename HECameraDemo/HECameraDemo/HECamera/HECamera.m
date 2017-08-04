//
//  HECamera.m
//  HECameraDemo
//
//  Created by weixhe on 2017/7/14.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HECamera.h"
#import "HESimpleCamera.h"
#import "HECameraBottomBar.h"
#import "HECameraTopBar.h"
#import "HECameraConstant.h"

@interface HECamera ()

@property (nonatomic, strong) HESimpleCamera *camera;

@end

@implementation HECamera

#pragma mark - Initialize
- (void)initialize {
    self.camera = [[HESimpleCamera alloc] initWithVideoEnabled:NO];
    [self.camera attachToViewController:self withFrame:self.view.bounds];
    self.camera.fixOrientationAfterCapture = YES;
    [self.camera start];
    
    [self.camera setBlockOnDeviceChange:^(HESimpleCamera *camera, AVCaptureDevice *device) {
        // 判断是否支持闪光灯，如果支持，则显示闪光灯按钮，如果不支持，则将闪光灯的按钮隐藏
        if ([camera isFlashAvailable]) {    // 支持
            
        } else {    // 不支持
            
        }
        
    }];
    
    [self.camera setBlockOnError:^(HESimpleCamera *camera, NSError *error) {
        if ([error.domain isEqualToString:HESimpleCameraErrorDomain]) {
            
            switch (error.code) {
                case HECameraErrorCodeCameraPermission:
                    NSLog(@"照相机授权失败");
                    break;
                case HECameraErrorCodeMicrophonePermission:
                    NSLog(@"麦克风授权失败");
                    break;
                case HECameraErrorCodeSession:
                    NSLog(@"创建会话失败");
                case HECameraErrorCodeVideoNotEnabled:
                    NSLog(@"不能录像");
                    break;
                    
                default:
                    break;
            }
        }
    }];
}

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // 初始化相机
    [self initialize];
    
    // 添加底部工具栏
    [self setupBottomBar];
    
    // 添加顶部工具栏
    [self setupTopBar];
    
    // 添加设置菜单
    [self setupSettings];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
#if __IPHONE_OS_VERSION_MAX_ALLOWED <= __IPHONE_9_0
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
#endif
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
#if __IPHONE_OS_VERSION_MAX_ALLOWED <= __IPHONE_9_0
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
#endif
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_9_0
- (BOOL)prefersStatusBarHidden {
    return YES;
}
#endif
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Setup UI
/*!
 *   @brief 创建底部的bar，包含了拍照和返回的功能
 */
- (void)setupBottomBar {
    
    HECameraBottomBar *bottomBar = [[HECameraBottomBar alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT - kDeviceScaleFactor(80), SCREEN_WIDTH, kDeviceScaleFactor(80))];
    [self.view addSubview:bottomBar];
    
    __weak typeof(self) weakSelf = self;
    // 点击快门，开始拍照
    bottomBar.BlockOnSnapImage = ^{
        [weakSelf.camera captureImage:^(HESimpleCamera *camera, UIImage *image, NSDictionary *metaData, NSError *error) {
            HELog(@"%@", image);
            HELog(@"%@", metaData);

        }];
    };
    
    // 点击取消，返回上一页
    bottomBar.BlockOnCancel = ^{
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    };
}

/*!
 *   @brief 创建顶部bar，包含了开启闪光灯，交换前后摄像头等功能
 */
- (void)setupTopBar {
    
    HECameraTopBar *topBar = [[HECameraTopBar alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, kDeviceScaleFactor(50))];
    [self.view addSubview:topBar];
    
    // 设置闪光灯的开关
    __weak typeof(self) weakSelf = self;
    topBar.BlockOnChangeFlashState = ^(HECameraFlash state) {
        [weakSelf.camera setFlashMode:state];
    };
    
    // 切换摄像头
    topBar.BlockOnToggleCameraPosition = ^{
        [weakSelf.camera togglePosition];
        HELog(@"togglePosition");
    };
    
    /*
        TODO: 此处需要添加一些动画效果，后期再补充
     */
}

/*!
 *   @brief 创建设置菜单
 */
- (void)setupSettings {
    
}

@end
