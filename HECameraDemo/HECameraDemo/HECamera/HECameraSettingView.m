//
//  HECameraSettingView.m
//  HECameraDemo
//
//  Created by weixhe on 2017/8/7.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HECameraSettingView.h"

@interface HECameraSettingView ()

@property (nonatomic, strong) UISlider *IOSSlider;

@end

@implementation HECameraSettingView

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
    [self setupSettingForISO];
}

/*!
 *   @brief 添加设置ISO的功能
 */
- (void)setupSettingForISO {
    UILabel *titleL = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.frame) - 30, 60, 30)];
    titleL.font = [UIFont systemFontOfSize:13];
    titleL.textAlignment = NSTextAlignmentRight;
    titleL.text = @"调节ISO";
    titleL.textColor = [UIColor whiteColor];
    [self addSubview:titleL];
    
    self.IOSSlider = [[UISlider alloc] initWithFrame:CGRectMake(CGRectGetMaxX(titleL.frame) + 10, CGRectGetMinY(titleL.frame), CGRectGetWidth(self.frame) - CGRectGetMaxX(titleL.frame) - 20, CGRectGetHeight(titleL.frame))];
    self.IOSSlider.minimumValue = 0.0;
    self.IOSSlider.maximumValue = 1.0;
    self.IOSSlider.value = 0;
    [self.IOSSlider addTarget:self action:@selector(onMoveSliderForChangedISOAction:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.IOSSlider];
    
}

#pragma mark - UISlider Action
- (void)onMoveSliderForChangedISOAction:(UISlider *)slider {
    if (self.BlockOnISOValueChanged) {
        self.BlockOnISOValueChanged(slider.value);
    }
}

#pragma mark - Setter
- (void)setCurrentISO:(CGFloat)currentISO {
    if (currentISO < 0 || currentISO > 1) {
        NSAssert(0 < currentISO < 1, @"感光度ISO越界[0...1]");
        return;
    }
    _currentISO = currentISO;
    self.IOSSlider.value = currentISO;
}

#pragma mark - Public Method


@end
