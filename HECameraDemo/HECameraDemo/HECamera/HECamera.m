//
//  HECamera.m
//  HECameraDemo
//
//  Created by weixhe on 2017/7/14.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HECamera.h"
#import "HESimpleCamera.h"
#import "HEBottomBar.h"


@interface HECamera ()

@property (nonatomic, strong) HESimpleCamera *camera;

@end

@implementation HECamera

#pragma mark - Initialize
- (void)initialize {
    self.camera = [[HESimpleCamera alloc] initWithVideoEnabled:NO];
    [self.camera attachToViewController:self withFrame:self.view.bounds];
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
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Setup UI
/*!
 *   @brief 创建底部的bar，包含了拍照和返回的功能
 */
- (void)setupBottomBar {
    
    HEBottomBar *bottomBar = [[HEBottomBar alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.frame) - 80, CGRectGetWidth(self.view.frame), 80)];
    [self.view addSubview:bottomBar];
    
    __weak typeof(self) weakSelf = self;
    
    bottomBar.BlockOnSnapImage = ^{
        
        [weakSelf.camera captureImage:^(HESimpleCamera *camera, UIImage *image, NSDictionary *metaData, NSError *error) {
            NSLog(@"%@", image);
            NSLog(@"%@", metaData);

        }];
    };
    
    bottomBar.BlockOnCancel = ^{
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    };
}

@end
