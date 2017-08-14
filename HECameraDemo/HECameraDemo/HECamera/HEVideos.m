//
//  HEVideos.m
//  HECameraDemo
//
//  Created by weixhe on 2017/8/8.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HEVideos.h"
#import "HECameraConstant.h"
#import "HESimpleCamera.h"
#import "HECameraBottomBar.h"

@interface HEVideos ()

@property (nonatomic, strong) HESimpleCamera *camera;

@end

@implementation HEVideos

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupCamera];
    [self setupBottomView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupCamera {
    self.camera = [[HESimpleCamera alloc] initWithQuality:AVCaptureSessionPresetHigh positon:HECameraPositionRear videoEnable:YES];
    [self.camera attachToViewController:self withFrame:self.view.bounds];
    [self.camera startSession];
    self.camera.autoSaveToPhotoAlbum = self.autoSaveToPhotoAlbum;
    
    self.camera.BlockOnDeviceChange = ^(HESimpleCamera *camera, AVCaptureDevice *device) {
        
    };
    self.camera.BlockOnError = ^(HESimpleCamera *camera, NSError *error) {
        
    };
}

- (void)setupBottomView {
    HECameraBottomBar *bottomView = [[HECameraBottomBar alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT - kDeviceScaleFactor(80), SCREEN_WIDTH, kDeviceScaleFactor(80))];
    [self.view addSubview:bottomView];
    bottomView.wantRecordVideo = YES;
    
    __weak typeof(self) weakSelf = self;
    bottomView.BlockOnCancel = ^{
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    };
    
    bottomView.BlockOnRecordVideo = ^(RecordVideoState state) {
      
        if (state == RecordVideoStateReady) {
            
        } else if (state == RecordVideoStateRecording) {
            
            if (weakSelf.camera.paused) {
                [weakSelf.camera resumeRecording];
            } else {
    
                [weakSelf.camera startRecordingWithOutputPath:weakSelf.videoPath progress:^(HESimpleCamera *camera, CGFloat time) {
                    if (weakSelf.BlockOnMonitoringRecord) {
                        weakSelf.BlockOnMonitoringRecord(time);
                    }
                }];
            }
            
        } else if (state == RecordVideoStatePause) {
            [weakSelf.camera pauseRecording];
        } else if (state == RecordVideoStateFinish) {
            
            [weakSelf.camera stopRecording:weakSelf.BlockOnFinishRecorded];
            if (weakSelf.navigationController.viewControllers.count > 0) {
                [weakSelf.navigationController popViewControllerAnimated:YES];
            } else {
                [weakSelf dismissViewControllerAnimated:YES completion:nil];
            }
        }
    };
}


@end
