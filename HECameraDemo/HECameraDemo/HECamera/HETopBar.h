//
//  HETopBar.h
//  HECameraDemo
//
//  Created by weixhe on 2017/7/25.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HESimpleCamera.h"

@interface HETopBar : UIView

@property (nonatomic, copy) void (^BlockOnChangeFlashState)(HECameraFlash state);

@end
