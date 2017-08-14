//
//  HEBottomBar.h
//  HECameraDemo
//
//  Created by weixhe on 2017/7/14.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, RecordVideoState) {
    RecordVideoStateReady,      // 准备, 需要重新拍摄时置为ready
    RecordVideoStateRecording,
    RecordVideoStatePause,
    RecordVideoStateFinish
};

@interface HECameraBottomBar : UIView

/*!
 *   @brief 拍照按钮事件回调
 */
@property (nonatomic, copy) void (^BlockOnSnapImage)();

/*!
 *   @brief 录像按钮开始或结束
 */
@property (nonatomic, copy) void (^BlockOnRecordVideo)(RecordVideoState state);

/*!
 *   @brief 取消按钮事件回调
 */
@property (nonatomic, copy) void (^BlockOnCancel)();

/*!
 *   @brief 显示设置模板
 */
@property (nonatomic, copy) void (^BlockOnShowSettings)();

@property (nonatomic, assign) BOOL wantRecordVideo;        // 是否想要录制视频

@end
