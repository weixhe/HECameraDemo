//
//  HERecordEncoder.h
//  HECameraDemo
//
//  Created by weixhe on 2017/8/9.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/*!
 *   @brief 写入并编码视频的的类
 */
@interface HERecordEncoder : NSObject

@property (nonatomic, strong, readonly) NSString *path;

/*!
 *  @brief 创建并返回实力对象
 *
 *  @param path         媒体存发路径
 *  @param height       视频分辨率的高
 *  @param width        视频分辨率的宽
 *  @param channel      音频通道
 *  @param rate         音频的采样比率
 *
 */
- (instancetype)initWithPath:(NSString *)path width:(NSInteger)width height:(NSInteger)height channels:(int)channel rate:(Float64)rate;
+ (instancetype)encoderWithPath:(NSString *)path width:(NSInteger)width height:(NSInteger)height channels:(int)channel rate:(Float64)rate;


/*!
 *  @brief 完成视频录制时调用
 */
- (void)finishWithCompletionHandler:(void (^)(void))handler;

/*!
 *  @brief 通过这个方法写入数据
 *
 *  @param sampleBuffer 写入的数据
 *  @param isVideo      是否写入的是视频
 */
- (BOOL)encodeFrame:(CMSampleBufferRef)sampleBuffer isVideo:(BOOL)isVideo;
@end
