//
//  HERecordEncoder.m
//  HECameraDemo
//
//  Created by weixhe on 2017/8/9.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HERecordEncoder.h"
//#import "HECameraConstant.h"

@interface HERecordEncoder ()

@property (nonatomic, strong) AVAssetWriter *writer;            // 媒体写入对象
@property (nonatomic, strong) AVAssetWriterInput *videoInput;   // 视频写入
@property (nonatomic, strong) AVAssetWriterInput *audioInput;   // 音频写入

@end

@implementation HERecordEncoder

- (void)dealloc {
    self.writer = nil;
    self.videoInput = nil;
    self.audioInput = nil;
}

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
- (instancetype)initWithPath:(NSString *)path width:(NSInteger)width height:(NSInteger)height channels:(int)channel rate:(Float64)rate {
    if (self = [super init]) {
        _path = path;
        
        // 清除原有文件
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        
        NSURL* url = [NSURL fileURLWithPath:self.path];
        // 初始化写入媒体类型为MP4类型
        self.writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeMPEG4 error:nil];
        // 使其更适合在网络上播放
        self.writer.shouldOptimizeForNetworkUse = YES;
        
        // 初始化视频输出
        [self initVideoInputHeight:height width:width];
        // 确保采集到rate和ch
        if (rate != 0 && channel != 0) {
            // 初始化音频输出
            [self initAudioInputChannels:channel samples:rate];
        }

    }
    return self;
}

+ (instancetype)encoderWithPath:(NSString *)path width:(NSInteger)width height:(NSInteger)height channels:(int)channel rate:(Float64)rate {
    return [[HERecordEncoder alloc] initWithPath:path width:width height:height channels:channel rate:rate];
}

// 初始化视频输入
- (void)initVideoInputHeight:(NSInteger)cy width:(NSInteger)cx {
    // 录制视频的一些配置，分辨率，编码方式等等
    NSDictionary* settings = @{AVVideoCodecKey : AVVideoCodecH264,
                               AVVideoWidthKey : @(cx),
                               AVVideoHeightKey : @(cy)};

    // 初始化视频写入类
    self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
    // 表明输入是否应该调整其处理为实时数据源的数据
    self.videoInput.expectsMediaDataInRealTime = YES;
    // 将视频输入源加入
    [self.writer addInput:self.videoInput];
}

// 初始化音频输入
- (void)initAudioInputChannels:(int)ch samples:(Float64)rate {
    // 音频的一些配置包括音频各种这里为AAC,音频通道、采样率和音频的比特率
    NSDictionary *settings = @{AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                               AVNumberOfChannelsKey : @(ch),
                               AVSampleRateKey : @(rate),
                               AVEncoderBitRateKey : @(128000)};
    // 初始化音频写入类
    self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:settings];
    // 表明输入是否应该调整其处理为实时数据源的数据
    self.audioInput.expectsMediaDataInRealTime = YES;
    // 将音频输入源加入
    [self.writer addInput:self.audioInput];
    
}

// 完成视频录制时调用
- (void)finishWithCompletionHandler:(void (^)(void))handler {
    [self.writer finishWritingWithCompletionHandler: handler];
}

// 通过这个方法写入数据
- (BOOL)encodeFrame:(CMSampleBufferRef) sampleBuffer isVideo:(BOOL)isVideo {
    // 数据是否准备写入
    if (CMSampleBufferDataIsReady(sampleBuffer)) {
        // 写入状态为未知,保证视频先写入
        if (self.writer.status == AVAssetWriterStatusUnknown && isVideo) {
            // 获取开始写入的CMTime
            CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            // 开始写入
            [self.writer startWriting];
            [self.writer startSessionAtSourceTime:startTime];
        }
        // 写入失败
        if (self.writer.status == AVAssetWriterStatusFailed) {
//            HELog(@"writer error %@", self.writer.error.localizedDescription);
            return NO;
        }
        // 判断是否是视频
        if (isVideo) {
            // 视频输入是否准备接受更多的媒体数据
            if (self.videoInput.readyForMoreMediaData == YES) {
                // 拼接数据
                [self.videoInput appendSampleBuffer:sampleBuffer];
                return YES;
            }
        } else {
            // 音频输入是否准备接受更多的媒体数据
            if (self.audioInput.readyForMoreMediaData) {
                // 拼接数据
                [self.audioInput appendSampleBuffer:sampleBuffer];
                return YES;
            }
        }
    }
    return NO;
}


@end
