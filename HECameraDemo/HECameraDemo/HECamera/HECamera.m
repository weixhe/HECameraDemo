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

@end

@implementation HECamera

#pragma mark - Initialize
- (void)initialize {
    HESimpleCamera *camera = [[HESimpleCamera alloc] initWithVideoEnabled:NO];
    [camera attachToViewController:self withFrame:self.view.bounds];
    [camera start];
    
    [camera setBlockOnError:^(HESimpleCamera *camera, NSError *error){
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
        
    };
    
    bottomBar.BlockOnCancel = ^{
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    };
}

@end
