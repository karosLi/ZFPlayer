//
//  ZFTXVodPlayerManager.h
//  TDXDVideoModule
//
//  Created by king on 2020/2/20.
//

#import <Foundation/Foundation.h>

#if __has_include(<ZFPlayer/ZFPlayerMediaPlayback.h>)
#import <ZFPlayer/ZFPlayerMediaPlayback.h>
#else
#import "ZFPlayerMediaPlayback.h"
#endif

#if __has_include(<TXLiteAVSDK_Professional/TXVodPlayer.h>)
#import <TXLiteAVSDK_Professional/TXVodPlayer.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const ZFTXVodPlayerErrorDomain;

@interface ZFTXVodPlayerManager : NSObject <ZFPlayerMediaPlayback>
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// 创建一个 ZFTXVodPlayerManager 实例
/// @param enableHWAcceleration 是否启用硬解码
/// @param config 点播配置
/// @return ZFTXVodPlayerManager 实例
///
/// config 默认配置
///
/// _config                    = [[TXVodPlayConfig alloc] init];
///
/// _config.playerType         = PLAYER_FFPLAY;
///
/// _config.progressInterval   = 1.0;
///
/// _config.enableAccurateSeek = YES;
///
/// _config.maxBufferSize      = 1;
///
- (instancetype)initWithEnableHWAcceleration:(BOOL)enableHWAcceleration config:(TXVodPlayConfig *)config;
@end

NS_ASSUME_NONNULL_END

#endif

