//
//  HESimpleCamera+Helper.h
//  HECameraDemo
//
//  Created by weixhe on 2017/7/13.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#import "HESimpleCamera.h"

@interface HESimpleCamera (Helper)

- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates
                                          previewLayer:(AVCaptureVideoPreviewLayer *)previewLayer
                                                 ports:(NSArray<AVCaptureInputPort *> *)ports;

- (UIImage *)cropImage:(UIImage *)image usingPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer;

@end
