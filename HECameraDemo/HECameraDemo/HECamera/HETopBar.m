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

@property (nonatomic, strong) UIButton *toggleBtn;

@end

@implementation HETopBar

- (void)dealloc
{
    self.flashContainerView = nil;
    self.BlockOnChangeFlashState = NULL;
    self.BlockOnToggleCameraPosition = NULL;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        expendFlash = YES;
        [self setup];
    }
    return self;
}

- (void)setup {
    
    self.flashContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, CGRectGetHeight(self.frame))];
    self.flashContainerView.clipsToBounds = YES;
    self.flashContainerView.backgroundColor = [UIColor colorWithWhite:1 alpha:0];
    [self addSubview:self.flashContainerView];
    
    UIButton *flashBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    flashBtn.frame = CGRectMake(0, 0, CGRectGetHeight(self.frame) + 10, CGRectGetHeight(self.frame));
    flashBtn.imageEdgeInsets = UIEdgeInsetsMake(0, 5, 0, 5);
    [flashBtn setImage:UIImageFromCameraBundle(@"flash") forState:UIControlStateNormal];
    [flashBtn addTarget:self action:@selector(onExpendFlashItems) forControlEvents:UIControlEventTouchUpInside];
    [self.flashContainerView addSubview:flashBtn];
    
    UIButton *openFlashBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    openFlashBtn.frame = CGRectMake(SCREEN_WIDTH / 2 - kDeviceScaleFactor(50) - CGRectGetHeight(self.frame), 0, CGRectGetHeight(self.frame), CGRectGetHeight(self.frame));
    [openFlashBtn setImage:UIImageFromCameraBundle(@"flash") forState:UIControlStateNormal];
//    [openFlashBtn setTitle:@"打开" forState:UIControlStateNormal];
    openFlashBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [openFlashBtn addTarget:self action:@selector(onOpenFlashAction) forControlEvents:UIControlEventTouchUpInside];
    [self.flashContainerView addSubview:openFlashBtn];
    
    UIButton *closeFlashBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeFlashBtn.frame = CGRectMake(SCREEN_WIDTH / 2 - CGRectGetHeight(self.frame) / 2, 0, CGRectGetHeight(self.frame), CGRectGetHeight(self.frame));
    [closeFlashBtn setImage:UIImageFromCameraBundle(@"flash-no") forState:UIControlStateNormal];
//    [closeFlashBtn setTitle:@"关闭" forState:UIControlStateNormal];
    closeFlashBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [closeFlashBtn addTarget:self action:@selector(onCloseFlashAction) forControlEvents:UIControlEventTouchUpInside];
    [self.flashContainerView addSubview:closeFlashBtn];
    
    UIButton *autoFlashBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    autoFlashBtn.frame = CGRectMake(SCREEN_WIDTH / 2 + kDeviceScaleFactor(50), 0, CGRectGetHeight(self.frame), CGRectGetHeight(self.frame));
    [autoFlashBtn setImage:UIImageFromCameraBundle(@"flash-auto") forState:UIControlStateNormal];
//    [autoFlashBtn setTitle:@"自动" forState:UIControlStateNormal];
    autoFlashBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [autoFlashBtn addTarget:self action:@selector(onAutoFlashAction) forControlEvents:UIControlEventTouchUpInside];
    [self.flashContainerView addSubview:autoFlashBtn];
    
    
    // 设置前后摄像头
    self.toggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.toggleBtn.frame = CGRectMake(SCREEN_WIDTH - CGRectGetHeight(self.frame), 0, CGRectGetHeight(self.frame), CGRectGetHeight(self.frame));
    [self.toggleBtn setImage:UIImageFromCameraBundle(@"camera-flip") forState:UIControlStateNormal];
    [self.toggleBtn addTarget:self action:@selector(onToggleCameraAction:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.toggleBtn];
    
    [self bringSubviewToFront:self.flashContainerView];
    [self onExpendFlashItems];

}

#pragma mark - UIButton Action

/*!
 *   @brief 展开闪光灯选项, 分别为打开，关闭，自动
 */
- (void)onExpendFlashItems {
    
    CGFloat width = expendFlash ? CGRectGetHeight(self.frame) + kDeviceScaleFactor(10) : SCREEN_WIDTH;
    self.flashContainerView.frame = CGRectMake(0, 0, width, CGRectGetHeight(self.frame));
    expendFlash = !expendFlash;
    self.toggleBtn.hidden = expendFlash;
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

/*!
 *   @brief 切换前后摄像头
 */
- (void)onToggleCameraAction:(UIButton *)button {
    button.userInteractionEnabled = NO;
    if (self.BlockOnToggleCameraPosition) {
        self.BlockOnToggleCameraPosition();
        [self rotationAimation:button];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        button.userInteractionEnabled = YES;
    });
}

#pragma mark - Animatin
- (void)rotationAimation:(UIView *)view {
    CABasicAnimation *rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.y"];
    rotation.toValue = [NSNumber numberWithFloat:M_PI];
    rotation.duration = 1.5f;
//    rotation.autoreverses = NO;
    [view.layer addAnimation:rotation forKey:@"rotation"];
}
@end
