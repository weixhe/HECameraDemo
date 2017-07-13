//
//  ViewController.m
//  HECameraDemo
//
//  Created by weixhe on 2017/7/11.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "ViewController.h"
#import "HESimpleCamera.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
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


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
