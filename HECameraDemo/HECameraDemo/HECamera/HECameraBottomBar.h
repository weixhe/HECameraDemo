//
//  HEBottomBar.h
//  HECameraDemo
//
//  Created by weixhe on 2017/7/14.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HECameraBottomBar : UIView

/*!
 *   @brief 拍照按钮事件回调
 */
@property (nonatomic, strong) void (^BlockOnSnapImage)();

/*!
 *   @brief 取消按钮事件回调
 */
@property (nonatomic, strong) void (^BlockOnCancel)();

@property (nonatomic, copy) void (^BlockOnShowSettings)();

@end
