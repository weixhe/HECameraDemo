//
//  HECameraConstant.h
//  HECameraDemo
//
//  Created by weixhe on 2017/7/25.
//  Copyright © 2017年 com.weixhe. All rights reserved.
//

#ifndef HECameraConstant_h
#define HECameraConstant_h

/*========================================输出打印============================================*/
#ifdef DEBUG
#define CameraLog(xx, ...)  NSLog(@"%s(%d行):\t\t" xx, __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define CameraLog(xx, ...)
#endif

#ifndef kDeviceScaleFactor
#define kDeviceScaleFactor(num)         ((num) * kDeviceScale)
#define kDeviceScale                    (SCREEN_WIDTH / 375.0)   // 用来适配frame，font等，根据屏幕的大小，适当改变，以iPhone6的宽度为基准
/** 这个参数,看公司项目UI图 具体是哪款机型,默认  iphone6
 RealUISrceenWidth  4/4s 5/5s 320.0  6/6s 375.0  6p/6sp 414.0
 RealUISrceenHeight 4/4s 修改480 5/5s 568.0  6/6s 667.0  6p/6sp 736.0  (备用)
 */
#endif

#ifndef SCREEN_WIDTH
#define SCREEN_WIDTH    ([[UIScreen mainScreen]bounds].size.width)      // 屏幕宽度
#define SCREEN_HEIGHT   ([[UIScreen mainScreen]bounds].size.height)     //屏幕高度
#endif


// 声明
static inline NSBundle * CameraBundle();



static inline UIImage * UIImageFromCameraBundle(NSString *imageName) {
    NSString *path = nil;
    
    NSString *extension = imageName.pathExtension;
    NSString *compent = imageName.stringByDeletingPathExtension;
    
    if ([extension isEqualToString:@"jpg"]) {
        path = [CameraBundle() pathForResource:compent ofType:@"jpg"];
    } else if ([extension isEqualToString:@"jpeg"]) {
        path = [CameraBundle() pathForResource:compent ofType:@"jpeg"];
    } else if ([extension isEqualToString:@"png"]) {
        path = [CameraBundle() pathForResource:compent ofType:@"png"];
    } else {
        if (extension.length == 0) {
            UIImage *image = nil;
            path = [CameraBundle().resourcePath stringByAppendingFormat:@"/%@.png", imageName];         // 优先尝试png
            image = [UIImage imageWithContentsOfFile:path];
            if (image) {
                return image;
            } else {
                path = [CameraBundle().resourcePath stringByAppendingFormat:@"/%@.jpg", imageName];     // 再次尝试jpg
                image = [UIImage imageWithContentsOfFile:path];
            }
            
            if (image) {
                return image;
            } else {
                path = [CameraBundle().resourcePath stringByAppendingFormat:@"/%@.jpeg", imageName];     // 再次尝试jpeg
                image = [UIImage imageWithContentsOfFile:path];
            }
            
            if (image) {
                return image;
            } else {
                CameraLog(@"特殊图片文件后缀，请添加处理方式");
            }
            
        } else {
            CameraLog(@"特殊图片文件后缀，请添加处理方式");
        }
    }
    return [UIImage imageWithContentsOfFile:path];
}


/*!
 *   @brief 返回本功能的bundle类
 */
static inline NSBundle * CameraBundle() {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"HESimpleCamera" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:path];
    return bundle;
}

#endif /* HECameraConstant_h */
