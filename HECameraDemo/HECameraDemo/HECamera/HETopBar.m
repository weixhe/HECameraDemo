//
//  HETopBar.m
//  HECameraDemo
//
//  Created by weixhe on 2017/7/25.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HETopBar.h"
#import "HECameraConstant.h"

@interface HETopBar () {
    BOOL expendFlash;
}

@property (nonatomic, strong) UIView *flashContainerView;

@end

@implementation HETopBar

- (void)dealloc
{
    self.flashContainerView = nil;
    self.BlockOnChangeFlashState = NULL;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
        expendFlash = NO;
        [self setup];
    }
    return self;
}

- (void)setup {
    
    self.flashContainerView = [[UIView alloc] initWithFrame:CGRectMake(kDeviceScaleFactor(5), 0, CGRectGetHeight(self.frame), CGRectGetHeight(self.frame))];
    self.flashContainerView.clipsToBounds = YES;
//    self.flashContainerView.backgroundColor = [UIColor redColor];
    [self addSubview:self.flashContainerView];
    
    UIButton *flashBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    flashBtn.frame = CGRectMake(0, 0, CGRectGetHeight(self.frame), CGRectGetHeight(self.frame));
    [flashBtn setImage:UIImageFromCameraBundle(@"camera-flash") forState:UIControlStateNormal];
    [flashBtn addTarget:self action:@selector(onExpendFlashItems) forControlEvents:UIControlEventTouchUpInside];
    [self.flashContainerView addSubview:flashBtn];
    
    UIButton *openFlashBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    openFlashBtn.frame = CGRectMake(CGRectGetMaxX(flashBtn.frame) + kDeviceScaleFactor(10), 0, CGRectGetHeight(self.frame), CGRectGetHeight(self.frame));
//    [openFlashBtn setImage:UIImageFromCameraBundle(@"camera-flash") forState:UIControlStateNormal];
    [openFlashBtn setTitle:@"打开" forState:UIControlStateNormal];
    openFlashBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [openFlashBtn addTarget:self action:@selector(onOpenFlashAction) forControlEvents:UIControlEventTouchUpInside];
    [self.flashContainerView addSubview:openFlashBtn];
    
    UIButton *closeFlashBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeFlashBtn.frame = CGRectMake(CGRectGetMaxX(openFlashBtn.frame) + kDeviceScaleFactor(10), 0, CGRectGetHeight(self.frame), CGRectGetHeight(self.frame));
//    [closeFlashBtn setImage:UIImageFromCameraBundle(@"camera-flash") forState:UIControlStateNormal];
    [closeFlashBtn setTitle:@"关闭" forState:UIControlStateNormal];
    closeFlashBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [closeFlashBtn addTarget:self action:@selector(onCloseFlashAction) forControlEvents:UIControlEventTouchUpInside];
    [self.flashContainerView addSubview:closeFlashBtn];
    
    UIButton *autoFlashBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    autoFlashBtn.frame = CGRectMake(CGRectGetMaxX(closeFlashBtn.frame) + kDeviceScaleFactor(10), 0, CGRectGetHeight(self.frame), CGRectGetHeight(self.frame));
//    [autoFlashBtn setImage:UIImageFromCameraBundle(@"camera-flash") forState:UIControlStateNormal];
    [autoFlashBtn setTitle:@"自动" forState:UIControlStateNormal];
    autoFlashBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [autoFlashBtn addTarget:self action:@selector(onAutoFlashAction) forControlEvents:UIControlEventTouchUpInside];
    [self.flashContainerView addSubview:autoFlashBtn];
}

#pragma mark - UIButton Action

/*!
 *   @brief 展开闪光灯选项, 分别为打开，关闭，自动
 */
- (void)onExpendFlashItems {
    
    CGFloat width = expendFlash ? CGRectGetHeight(self.frame) : CGRectGetHeight(self.frame) * 6;
    self.flashContainerView.frame = CGRectMake(kDeviceScaleFactor(5), 0, width, CGRectGetHeight(self.frame));
    expendFlash = !expendFlash;
}

/*!
 *   @brief 打开闪光灯
 */
- (void)onOpenFlashAction {
    if (self.BlockOnChangeFlashState) {
        self.BlockOnChangeFlashState(HECameraFlashOn);
    }
    [self onExpendFlashItems];
}

/*!
 *   @brief 关闭闪光灯
 */
- (void)onCloseFlashAction {
    if (self.BlockOnChangeFlashState) {
        self.BlockOnChangeFlashState(HECameraFlashOff);
    }
    [self onExpendFlashItems];
}

/*!
 *   @brief 自动闪光灯
 */
- (void)onAutoFlashAction {
    if (self.BlockOnChangeFlashState) {
        self.BlockOnChangeFlashState(HECameraFlashAuto);
    }
    [self onExpendFlashItems];
}

@end
