//
//  HEVideos.h
//  HECameraDemo
//
//  Created by weixhe on 2017/8/8.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HEVideos : UIViewController

@property (nonatomic, copy) void (^BlockOnMonitoringRecord)(CGFloat time);

@property (nonatomic, copy) void (^BlockOnFinishRecorded)(UIImage *thumb, NSString *path);

@property (nonatomic, copy) NSString * videoPath;       // 放置video的路径，若为空，则路径为(Library/he_videos/xxx.mp4)

@property (nonatomic, assign) BOOL autoSaveToPhotoAlbum;        // 是否保存到相册

@end
