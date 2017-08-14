//
//  ViewController.m
//  HECameraDemo
//
//  Created by weixhe on 2017/7/11.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "ViewController.h"
#import "HECamera.h"
#import "HEVideos.h"
#import "HERecordMoviesViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *first = [UIButton buttonWithType:UIButtonTypeCustom];
    first.frame = CGRectMake(0, 0, 80, 44);
    first.center = CGPointMake(self.view.frame.size.width / 2, 100);
    [first setTitle:@"照相机" forState:UIControlStateNormal];
    first.backgroundColor = [UIColor colorWithRed:143/255.0 green:110/255.0 blue:246/255.0 alpha:1];
    [first addTarget:self action:@selector(onFirstAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:first];
    
    UIButton *second = [UIButton buttonWithType:UIButtonTypeCustom];
    second.frame = CGRectMake(100, 0, 80, 44);
    second.center = CGPointMake(self.view.frame.size.width / 2, 160);
    [second setTitle:@"录像机" forState:UIControlStateNormal];
    second.backgroundColor = [UIColor colorWithRed:125/255.0 green:248/255.0 blue:246/255.0 alpha:1];
    [second addTarget:self action:@selector(onSecondAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:second];

    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)onFirstAction {
    HECamera *camera = [[HECamera alloc] init];
    [self presentViewController:camera animated:YES completion:nil];
}

- (void)onSecondAction {
    HERecordMoviesViewController *recordMovieVC = [[HERecordMoviesViewController alloc] init];
    [self.navigationController pushViewController:recordMovieVC animated:YES];
}

@end
