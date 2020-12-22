//
//  ZFTXVodPlayerManager.m
//  TDXDVideoModule
//
//  Created by king on 2020/2/20.
//

#import "ZFTXVodPlayerManager.h"

#if __has_include(<ZFPlayer/ZFPlayer.h>)
#import <ZFPlayer/ZFPlayer.h>
#else
#import "ZFPlayer.h"
#endif

#if __has_include(<TXLiteAVSDK_Professional/TXVodPlayer.h>)
#import <TXLiteAVSDK_Professional/TXVodPlayer.h>

#import <TDXDBaseModule/TDXDAccountManager.h>
#import <TDXDVMModule/TDXDRequestConfigure.h>

NSErrorDomain const ZFTXVodPlayerErrorDomain = @"ZFTXVodPlayerErrorDomain";

typedef void (^ZFTXVodPlayerStateAction)(NSDictionary *params);

@interface ZFTXVodPlayerAttachView : UIView

@end

@implementation ZFTXVodPlayerAttachView

@end

@interface ZFTXVodPlayerManager () <TXVodPlayListener>
@property (nonatomic, strong) TXVodPlayer *player;
@property (nonatomic, assign) BOOL isReadyToPlay;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, ZFTXVodPlayerStateAction> *stateActions;
@property (nonatomic, strong) ZFTXVodPlayerAttachView *attachView;
@property (nonatomic, assign) BOOL enableHWAcceleration;
@property (nonatomic, strong) TXVodPlayConfig *config;
@end

@implementation ZFTXVodPlayerManager
@synthesize view                    = _view;
@synthesize currentTime             = _currentTime;
@synthesize totalTime               = _totalTime;
@synthesize playerPlayTimeChanged   = _playerPlayTimeChanged;
@synthesize playerBufferTimeChanged = _playerBufferTimeChanged;
@synthesize playerDidToEnd          = _playerDidToEnd;
@synthesize bufferTime              = _bufferTime;
@synthesize playState               = _playState;
@synthesize loadState               = _loadState;
@synthesize assetURL                = _assetURL;
@synthesize playerPrepareToPlay     = _playerPrepareToPlay;
@synthesize playerReadyToPlay       = _playerReadyToPlay;
@synthesize playerPlayStateChanged  = _playerPlayStateChanged;
@synthesize playerLoadStateChanged  = _playerLoadStateChanged;
@synthesize seekTime                = _seekTime;
@synthesize muted                   = _muted;
@synthesize volume                  = _volume;
@synthesize presentationSize        = _presentationSize;
@synthesize isPlaying               = _isPlaying;
@synthesize rate                    = _rate;
@synthesize isPreparedToPlay        = _isPreparedToPlay;
@synthesize shouldAutoPlay          = _shouldAutoPlay;
@synthesize scalingMode             = _scalingMode;
@synthesize playerPlayFailed        = _playerPlayFailed;
@synthesize presentationSizeChanged = _presentationSizeChanged;

- (void)dealloc {
	ZFPlayerLog(@"[%@ dealloc]", NSStringFromClass(self.class));
	[self stop];
}

- (instancetype)initWithEnableHWAcceleration:(BOOL)enableHWAcceleration config:(TXVodPlayConfig *)config {
	if (self == [super init]) {
		self.enableHWAcceleration = enableHWAcceleration;
		self.config               = config;
		[self commonInit];
		[self initStateActions];
	}
	return self;
}

- (void)commonInit {

	_scalingMode    = ZFPlayerScalingModeAspectFit;
	_shouldAutoPlay = YES;

	if (!self.config) {
		_config                    = [[TXVodPlayConfig alloc] init];
		_config.playerType         = PLAYER_FFPLAY;
		_config.progressInterval   = 1.0;
		_config.enableAccurateSeek = YES;
		_config.maxBufferSize      = 5;
	}
}

- (void)initStateActions {
	@weakify(self);
	/* clang-format off */
    [self bindState:WARNING_LIVE_STREAM_SERVER_RECONNECT action:^(NSDictionary *params) {
        @strongify(self);
        // 网络断连, 已启动自动重连（自动重连连续失败超过三次会放弃）
        self.loadState = ZFPlayerLoadStatePrepare;
    }];

    [self bindState:ERR_PLAY_LIVE_STREAM_NET_DISCONNECT action:^(NSDictionary *params) {
        @strongify(self);
        // 网络断连，且经多次重连抢救无效，可以放弃治疗，更多重试请自行重启播放
        self.loadState = ZFPlayerLoadStateUnknown;
        NSError *error = [NSError errorWithDomain:ZFTXVodPlayerErrorDomain code:0 userInfo:params];
        self.playState = ZFPlayerPlayStatePlayFailed;
        !self.playerPlayFailed ?: self.playerPlayFailed(self, error);
    }];

    [self bindState:PLAY_EVT_VOD_PLAY_PREPARED action:^(NSDictionary *params) {
        @strongify(self);
        // 准备好
        ZFPlayerLog(@"准备好了....");
        self.isReadyToPlay = YES;
        self.loadState     = ZFPlayerLoadStatePlaythroughOK;
        self->_currentTime = 0;
        self->_totalTime   = self.player.duration;
        self->_bufferTime  = self.player.playableDuration;
        if (self.shouldAutoPlay) {
            self.loadState = ZFPlayerLoadStatePlayable;
            [self.player setMute:self.muted];
            if (self.seekTime > 0) {
                [self seekToTime:self.seekTime completionHandler:nil];
                self.seekTime = 0;  // 滞空, 防止下次播放出错
            }
            [self play];
            [self.player setMute:self.muted];
        } else {
            self.seekTime = 0;
        }
        !self.playerReadyToPlay ?: self.playerReadyToPlay(self, self.assetURL);
    }];

    [self bindState:PLAY_EVT_PLAY_LOADING action:^(NSDictionary *params) {
        @strongify(self);
        // loading
        NSTimeInterval currentTime = self.currentTime;
        NSTimeInterval bufferTime = self.bufferTime;
        ZFPlayerLog(@"loading currentTime: %f   bufferTime: %f", currentTime, bufferTime);
//        if (bufferTime - currentTime < 5.0) self.loadState = ZFPlayerLoadStateStalled;
        self.loadState = ZFPlayerLoadStateStalled;
        [self progressUpdate];
    }];

    [self bindState:PLAY_EVT_VOD_LOADING_END action:^(NSDictionary *params) {
        @strongify(self);
        // loading 完毕
        NSTimeInterval currentTime = self.currentTime;
        NSTimeInterval bufferTime = self.bufferTime;
        ZFPlayerLog(@"loading 完毕 currentTime: %f   bufferTime: %f", currentTime, bufferTime);
        self.loadState = ZFPlayerLoadStatePlaythroughOK;
        [self progressUpdate];
    }];

    [self bindState:PLAY_EVT_PLAY_BEGIN action:^(NSDictionary *params) {
        @strongify(self);
        // 开始播放
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
            ZFPlayerLog(@"开始播放....");
            self->_isPlaying = YES;
            self.playState   = ZFPlayerPlayStatePlaying;
            [self progressUpdate];
        } else {
            [self pause];
        }
    }];

    [self bindState:PLAY_EVT_PLAY_PROGRESS action:^(NSDictionary *params) {
        @strongify(self);
        // 进度回调
        if (self.playState == ZFPlayerPlayStatePlaying) {
            NSTimeInterval currentTime = self.currentTime;
            NSTimeInterval bufferTime = self.bufferTime;
            ZFPlayerLog(@"播放进度回调 currentTime: %f   bufferTime: %f", currentTime, bufferTime);
            [self progressUpdate];
            if (self.loadState == ZFPlayerLoadStateStalled && ((bufferTime - currentTime) >= 5.0)) {
                self.loadState = ZFPlayerLoadStatePlayable;
            }
        }
    }];

    [self bindState:PLAY_EVT_PLAY_END action:^(NSDictionary *params) {
        @strongify(self);
        // 结束播放
        ZFPlayerLog(@"结束播放....");
        self.playState = ZFPlayerPlayStatePlayStopped;
//        [self progressUpdate];
        self->_currentTime = self.totalTime;
        if (self.playerPlayTimeChanged) self.playerPlayTimeChanged(self, self.currentTime, self.totalTime);
        !self.playerDidToEnd ?: self.playerDidToEnd(self);
    }];

    [self bindState:PLAY_EVT_GET_PLAYINFO_SUCC action:^(NSDictionary *params) {
        @strongify(self);
        // 获取点播文件信息成功
        ZFPlayerLog(@"获取点播文件信息成功....");
        self->_presentationSize = CGSizeMake(self.player.width, self.player.height);
        !self.presentationSizeChanged ?: self.presentationSizeChanged(self, self->_presentationSize);
    }];

    [self bindState:PLAY_ERR_GET_PLAYINFO_FAIL action:^(NSDictionary *params) {
        @strongify(self);
        // 获取点播文件信息失败
        ZFPlayerLog(@"获取点播文件信息失败....");
        NSError *error = [NSError errorWithDomain:ZFTXVodPlayerErrorDomain code:0 userInfo:params];
        self.playState = ZFPlayerPlayStatePlayFailed;
        !self.playerPlayFailed ?: self.playerPlayFailed(self, error);
    }];

    [self bindState:PLAY_EVT_CHANGE_RESOLUTION action:^(NSDictionary *params) {
        @strongify(self);
        // 视频分辨率改变
        ZFPlayerLog(@"视频分辨率改变....");
        self->_presentationSize = CGSizeMake(self.player.width, self.player.height);
        !self.presentationSizeChanged ?: self.presentationSizeChanged(self, self->_presentationSize);
    }];

    [self bindState:EVT_DOWN_CHANGE_RESOLUTION action:^(NSDictionary *params) {
        @strongify(self);
        // 下行视频分辨率改变
        ZFPlayerLog(@"下行视频分辨率改变....");
        self->_presentationSize = CGSizeMake(self.player.width, self.player.height);
        !self.presentationSizeChanged ?: self.presentationSizeChanged(self, self->_presentationSize);
    }];

    [self bindState:EVT_START_VIDEO_DECODER action:^(NSDictionary *params) {
        @strongify(self);
        // 解码器启动
        ZFPlayerLog(@"解码器启动....");
    }];
	/* clang-format on */
}

- (void)bindState:(NSInteger)state action:(ZFTXVodPlayerStateAction)action {
	if (!action) return;
	if (!self.stateActions) self.stateActions = [NSMutableDictionary<NSNumber *, ZFTXVodPlayerStateAction> dictionaryWithCapacity:10];
	self.stateActions[@(state)] = action;
}

- (ZFTXVodPlayerStateAction)actionForState:(NSInteger)state {
	return self.stateActions[@(state)];
}

- (void)prepareToPlay {
	if (!_assetURL) return;
	[self initializePlayer];
	if (self.shouldAutoPlay) {
		[self play];
		self.loadState = ZFPlayerLoadStatePrepare;
	}
	!self.playerPrepareToPlay ?: self.playerPrepareToPlay(self, self.assetURL);
}

- (void)reloadPlayer {
	[self prepareToPlay];
}

- (void)play {
	if (!_isPreparedToPlay) {
		[self prepareToPlay];
	} else {
		if (self.player.config.playerType == PLAYER_AVPLAYER) {
			_isPlaying     = YES;
			self.playState = ZFPlayerPlayStatePlaying;
		}
		[self.player resume];
		[self.player setRate:self.rate];
		if (self.player.isPlaying) {
			_isPlaying     = YES;
			self.playState = ZFPlayerPlayStatePlaying;
		}
	}
}

- (void)pause {
	[self.player pause];
	_isPlaying     = NO;
	self.playState = ZFPlayerPlayStatePaused;
}

- (void)stop {
	if (!self.player) return;
	[self.player stopPlay];
	[self.player removeVideoWidget];
	self.player        = nil;
	_isPlaying         = NO;
	_isPreparedToPlay  = NO;
	self->_currentTime = 0;
	self->_totalTime   = 0;
	self->_bufferTime  = 0;
	self.isReadyToPlay = NO;
	self.playState     = ZFPlayerPlayStatePlayStopped;
}

- (void)replay {
	@weakify(self);
	if (self.player.currentPlaybackTime > 0.0) {
		/* clang-format off */
        [self seekToTime:0 completionHandler:^(BOOL finished) {
            @strongify(self)
            [self play];
        }];
		/* clang-format on */
	} else {
		if (self.playState == ZFPlayerPlayStatePlayFailed || !self.isReadyToPlay) {
			[self reloadPlayer];
		}
	}
}

- (void)seekToTime:(NSTimeInterval)time completionHandler:(void (^__nullable)(BOOL finished))completionHandler {
	if (!self.player) {
		if (completionHandler) completionHandler(NO);
		return;
	}
	if (self.player.duration > 0) {
		[self.player seek:time];
		if (completionHandler) completionHandler(YES);
	} else {
		self.seekTime = time;
	}
}

- (UIImage *)thumbnailImageAtCurrentTime {
	if (!self.player) {
		return nil;
	}
	dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
	__block UIImage *image         = nil;
	[self.player snapshot:^(UIImage *img) {
		image = img;
		dispatch_semaphore_signal(semaphore);
	}];

	dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 1.0f * NSEC_PER_SEC);
	if (dispatch_semaphore_wait(semaphore, timeout) != 0) return nil;
	return image;
	//    return [self.player thumbnailImageAtCurrentTime];
}

//- (NSTimeInterval)currentTime {
//    return self.isReadyToPlay ? self.player.currentPlaybackTime : 0;
//}
//
//- (NSTimeInterval)totalTime {
//    return self.isReadyToPlay ? self.player.duration : 0;
//}
//
//- (NSTimeInterval)bufferTime {
//    return self.isReadyToPlay ? self.player.playableDuration : 0;
//}
#pragma mark - private method

- (void)initializePlayer {
	if (self.player) {
		[self stop];
	}

	_isPreparedToPlay = YES;

	self.player                      = [[TXVodPlayer alloc] init];
	self.player.config               = self.config;
	self.player.isAutoPlay           = self.shouldAutoPlay;
	self.player.enableHWAcceleration = self.enableHWAcceleration;
	self.player.vodDelegate          = self;
	self.scalingMode                 = self->_scalingMode;

	[self.view insertSubview:self.attachView atIndex:0];
	self.attachView.frame            = self.view.bounds;
	self.attachView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.player setupVideoWidget:self.attachView insertIndex:0];

	NSURLComponents *cmp                         = [NSURLComponents componentsWithURL:self.assetURL resolvingAgainstBaseURL:NO];
	NSMutableArray<NSURLQueryItem *> *queryItems = cmp.queryItems.mutableCopy ?: @[].mutableCopy;
	[queryItems addObject:[NSURLQueryItem queryItemWithName:@"sign" value:Account.sign ?: @""]];
	cmp.queryItems = queryItems;
	NSURL *url     = cmp.URL;
	[self.player startPlay:url.absoluteString];
}

- (void)progressUpdate {
	//    if (self.player.currentPlaybackTime > 0.0 && !self.isReadyToPlay) {
	//        self.isReadyToPlay = YES;
	//        self.loadState     = ZFPlayerLoadStatePlaythroughOK;
	//    }
	self->_currentTime = self.player.currentPlaybackTime > 0.0 ? self.player.currentPlaybackTime : 0.0;
	self->_totalTime   = self.player.duration;
	self->_bufferTime  = self.player.playableDuration;
	if (self.playerPlayTimeChanged) self.playerPlayTimeChanged(self, self.currentTime, self.totalTime);
	if (self.playerBufferTimeChanged) self.playerBufferTimeChanged(self, self.bufferTime);
}
#pragma mark - TXVodPlayListener
/**
 * 点播事件通知
 *
 * @param player 点播对象
 * @param EvtID 参见TXLiveSDKTypeDef.h
 * @param param 参见TXLiveSDKTypeDef.h
 * @see TXVodPlayer
 */
- (void)onPlayEvent:(TXVodPlayer *)player event:(int)EvtID withParam:(NSDictionary *)param {
	ZFTXVodPlayerStateAction action = [self actionForState:EvtID];
	!action ?: action(param);
	ZFPlayerLog(@"TXVodPlayer ::: onPlayEvent %d", EvtID);
}

/**
 * 网络状态通知
 *
 * @param player 点播对象
 * @param param 参见TXLiveSDKTypeDef.h
 * @see TXVodPlayer
 */
- (void)onNetStatus:(TXVodPlayer *)player withParam:(NSDictionary *)param {
	//    ZFPlayerLog(@"TXVodPlayer ::: onNetStatus %@", param);
}

#pragma mark - getter

- (UIView *)view {
	if (!_view) {
		_view = [[ZFPlayerView alloc] init];
	}
	return _view;
}

- (ZFTXVodPlayerAttachView *)attachView {
	if (!_attachView) {
		_attachView                 = [[ZFTXVodPlayerAttachView alloc] init];
		_attachView.backgroundColor = UIColor.clearColor;
	}
	return _attachView;
}

#pragma mark - oevrride getter
- (float)rate {
	return _rate == 0 ? 1 : _rate;
}

#pragma mark - setter

- (void)setPlayState:(ZFPlayerPlaybackState)playState {
	//    if (_playState != playState) return;
	_playState = playState;
	!self.playerPlayStateChanged ?: self.playerPlayStateChanged(self, playState);
}

- (void)setLoadState:(ZFPlayerLoadState)loadState {
	//    if (_loadState != loadState) return;
	_loadState = loadState;
	!self.playerLoadStateChanged ?: self.playerLoadStateChanged(self, loadState);
}

- (void)setAssetURL:(NSURL *)assetURL {
	if (self.player) {
		[self stop];
	}
	_assetURL = assetURL;
	[self prepareToPlay];
}

- (void)setRate:(float)rate {
	if (self.player && fabsf(rate) > 0.00001f) {
		[self.player setRate:rate];
	}
	_rate = rate;
}

- (void)setMuted:(BOOL)muted {
	_muted = muted;
	[self.player setMute:muted];
}

- (void)setScalingMode:(ZFPlayerScalingMode)scalingMode {
	_scalingMode = scalingMode;
	switch (scalingMode) {
		case ZFPlayerScalingModeFill:
			[self.player setRenderMode:RENDER_MODE_FILL_SCREEN];
			break;
		default:
			[self.player setRenderMode:RENDER_MODE_FILL_EDGE];
			break;
	}
}

- (void)setVolume:(float)volume {
	_volume = MIN(MAX(0, volume), 1);
}

@end

#endif

