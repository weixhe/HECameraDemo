//
//  HETopBar.h
//  HECameraDemo
//
//  Created by weixhe on 2017/7/25.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HESimpleCamera.h"

@interface HECameraTopBar : UIView

@property (nonatomic, copy) void (^BlockOnChangeFlashState)(HECameraFlash state);       // 改变闪光灯的状态

@property (nonatomic, copy) void (^BlockOnToggleCameraPosition)();      // 切换照相机的摄像头

@end
