//
//  HEBottomBar.m
//  HECameraDemo
//
//  Created by weixhe on 2017/7/14.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HEBottomBar.h"
#import "HECameraConstant.h"

@interface HEBottomBar ()

@property (nonatomic, strong) UIButton *snapButton;

@property (nonatomic, strong) UIButton *cancelButton;

@end

@implementation HEBottomBar

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
    [self.cancelButton setImage:UIImageFromCameraBundle(@"closeButton") forState:UIControlStateNormal];
    [self.cancelButton addTarget:self action:@selector(onCancelAction:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.cancelButton];
    
}

- (void)layoutSubviews {
    
    self.snapButton.frame = CGRectMake(0, 0, CGRectGetHeight(self.frame), CGRectGetHeight(self.frame));
    self.snapButton.center = CGPointMake(CGRectGetWidth(self.frame) / 2, CGRectGetHeight(self.frame) / 2);
    
    self.cancelButton.frame = CGRectMake(0, 0, kDeviceScaleFactor(45), kDeviceScaleFactor(45));
    self.cancelButton.center = CGPointMake(kDeviceScaleFactor(30), CGRectGetHeight(self.frame) / 2);
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

@end
