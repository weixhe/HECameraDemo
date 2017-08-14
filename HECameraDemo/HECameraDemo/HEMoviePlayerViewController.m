//
//  HEMoviePlayerViewController.m
//  HECameraDemo
//
//  Created by weixhe on 2017/8/14.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HEMoviePlayerViewController.h"
#import "ZFPlayer.h"
@interface HEMoviePlayerViewController () <ZFPlayerDelegate>

@property (nonatomic, strong) ZFPlayerView *playerView;

@property (nonatomic, strong) ZFPlayerModel *playerModel;

@end

@implementation HEMoviePlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIView *fatherView = [[UIView alloc] initWithFrame:CGRectMake(0, 64, ScreenWidth, 155)];
    [self.view addSubview:fatherView];
    
    self.playerModel = [[ZFPlayerModel alloc] init];
    self.playerModel.videoURL = [NSURL URLWithString:[NSString stringWithFormat:@"file://%@", self.movieUrl]];
    self.playerModel.title = self.movieTitle;
    self.playerModel.placeholderImage = [UIImage imageWithContentsOfFile:self.moviePlaceholderPath];
    self.playerModel.fatherView = fatherView;
    
    self.playerView = [[ZFPlayerView alloc] init];
    self.playerView.delegate = self;
    [self.playerView playerControlView:nil playerModel:self.playerModel];
    // 自动播放，默认不自动播放
    [self.playerView autoPlayTheVideo];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
    return ZFPlayerShared.isStatusBarHidden;
}

// 返回值要必须为NO
- (BOOL)shouldAutorotate {
    return NO;
}

#pragma mark - ZFPlayerDelegate

- (void)zf_playerBackAction {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
