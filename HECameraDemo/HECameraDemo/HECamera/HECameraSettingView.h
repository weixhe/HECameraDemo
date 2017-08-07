//
//  HECameraSettingView.h
//  HECameraDemo
//
//  Created by weixhe on 2017/8/7.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HECameraSettingView : UIView

@property (nonatomic, copy) void (^BlockOnISOValueChanged)(CGFloat ISO);

@property (nonatomic, assign) CGFloat currentISO;

@end
