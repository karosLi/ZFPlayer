//
//  ZFTXVodPlayConfig.m
//  ZFPlayer_Example
//
//  Created by karos li on 2020/12/22.
//  Copyright © 2020 紫枫. All rights reserved.
//

#import "ZFTXVodPlayConfig.h"
#if __has_include(<TXLiteAVSDK_Player/TXVodPlayer.h>)
#import <TXLiteAVSDK_Player/TXVodPlayer.h>
#endif

@implementation ZFTXVodPlayConfig

+ (instancetype)defaultConfig {
    ZFTXVodPlayConfig *config = [ZFTXVodPlayConfig new];
    config.cacheFolderPath = [self defaultCacheFolderPath];
    config.maxCacheItem = 20;
    return config;
}

+ (NSString *)defaultCacheFolderPath {
    return [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString:@"/ZFTXCache"];
}

- (instancetype)init {
    self = [super init];
    self.hwAcceleration = YES;
    return self;
}

@end
