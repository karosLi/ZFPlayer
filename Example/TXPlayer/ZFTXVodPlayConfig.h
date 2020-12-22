//
//  ZFTXVodPlayConfig.h
//  ZFPlayer_Example
//
//  Created by karos li on 2020/12/22.
//  Copyright © 2020 紫枫. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// TXVod 播放器配置参数
@interface ZFTXVodPlayConfig : NSObject

/// 默认配置
/// hwAcceleration：YES
/// cacheFolderPath：全局缓存目录
/// maxCacheItem: 20
+ (instancetype)defaultConfig;

/// 默认视频缓存目录
+ (NSString *)defaultCacheFolderPath;

/// 是否硬件加速，默认YES
@property (nonatomic, assign) BOOL hwAcceleration;

/// 播放器类型 0: FFmepg，1:AVPlayer，默认 0
@property (nonatomic, assign) NSInteger playerType;

/// 视频缓存目录，默认不缓存。当播放器类型为 FFmepg 时，缓存才生效
@property (nonatomic, copy, nullable) NSString *cacheFolderPath;

/// 播放器最大缓存个数，默认 0
@property (nonatomic, assign) NSInteger maxCacheItem;

/// 起始播放时间，用于从上次位置开播，默认 0
@property (nonatomic, assign) CGFloat startTime;

@end

NS_ASSUME_NONNULL_END
