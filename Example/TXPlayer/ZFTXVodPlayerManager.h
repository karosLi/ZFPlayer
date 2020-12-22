//
//  ZFTXVodPlayerManager.h
//  ZFPlayer_Example
//
//  Created by karos li on 2020/12/22.
//  Copyright © 2020 紫枫. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZFTXVodPlayConfig.h"

#if __has_include(<ZFPlayer/ZFPlayerMediaPlayback.h>)
#import <ZFPlayer/ZFPlayerMediaPlayback.h>
#else
#import "ZFPlayerMediaPlayback.h"
#endif

NS_ASSUME_NONNULL_BEGIN
/// TXVod 播放管理器
@interface ZFTXVodPlayerManager : NSObject<ZFPlayerMediaPlayback>
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// 创建一个 ZFTXVodPlayerManager 实例
/// @param config  config 点播配置
- (instancetype)initWithConfig:(ZFTXVodPlayConfig *)config;

@end

NS_ASSUME_NONNULL_END
