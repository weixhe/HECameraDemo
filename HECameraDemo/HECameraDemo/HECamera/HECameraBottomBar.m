//
//  HEBottomBar.m
//  HECameraDemo
//
//  Created by weixhe on 2017/7/14.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HECameraBottomBar.h"
#import "HECameraConstant.h"

@interface HECameraBottomBar ()

@property (nonatomic, strong) UIButton *snapButton;

@property (nonatomic, strong) UIButton *cancelButton;

@property (nonatomic, strong) UIButton *settingButton;

@end

@implementation HECameraBottomBar

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
        [self setup];
    }
    return self;
}

- (void)setup {
    
    self.snapButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGFloat padding = kDeviceScaleFactor(10);
    self.snapButton.imageEdgeInsets = UIEdgeInsetsMake(padding, padding, padding, padding);
    [self.snapButton setImage:UIImageFromCameraBundle(@"cameraButton") forState:UIControlStateNormal];
    [self.snapButton addTarget:self action:@selector(onSnapImageAction:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.snapButton];
    
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.cancelButton setTitle:@"取消" forState:UIControlStateNormal];
    self.cancelButton.titleLabel.font = [UIFont systemFontOfSize:kDeviceScaleFactor(20)];
    [self.cancelButton addTarget:self action:@selector(onCancelAction:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.cancelButton];
    
    self.settingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.settingButton setImage:UIImageFromCameraBundle(@"settings") forState:UIControlStateNormal];
    [self.settingButton addTarget:self action:@selector(onClickSettingAction:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.settingButton];
    
}

- (void)layoutSubviews {
    
    self.snapButton.frame = CGRectMake(0, 0, CGRectGetHeight(self.frame), CGRectGetHeight(self.frame));
    self.snapButton.center = CGPointMake(CGRectGetWidth(self.frame) / 2, CGRectGetHeight(self.frame) / 2);
    
    self.cancelButton.frame = CGRectMake(0, 0, CGRectGetHeight(self.frame), CGRectGetHeight(self.frame));
    self.cancelButton.center = CGPointMake(kDeviceScaleFactor(30), CGRectGetHeight(self.frame) / 2);
    
    self.settingButton.frame = CGRectMake(0, 0, CGRectGetHeight(self.frame), CGRectGetHeight(self.frame));
    self.settingButton.center = CGPointMake(CGRectGetWidth(self.frame) - CGRectGetHeight(self.frame) / 2, CGRectGetHeight(self.frame) / 2);
}

#pragma mark - UIButton Action

/*!
 *   @brief 按钮事件 - 拍照
 */
- (void)onSnapImageAction:(UIButton *)button {
    if (self.BlockOnSnapImage) {
        self.BlockOnSnapImage();
    }
}

/*!
 *   @brief 按钮事件 - 取消
 */
- (void)onCancelAction:(UIButton *)button {
    if (self.BlockOnCancel) {
        self.BlockOnCancel();
    }
}

/*!
 *   @brief 按钮事件 - 设置功能，显示、隐藏设置面板
 */
- (void)onClickSettingAction:(UIButton *)button {
    if (self.BlockOnShowSettings) {
        self.BlockOnShowSettings();
    }
}

@end
