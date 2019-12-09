// Copyright 2019-present 650 Industries. All rights reserved.

#import <EXScreenOrientation/EXScreenOrientationModule.h>
#import <UMCore/UMEventEmitterService.h>
#import <EXScreenOrientation/EXScreenOrientationRegistry.h>
#import <UMCore/UMModuleRegistryProvider.h>
#import <EXScreenOrientation/EXScreenOrientationUtilities.h>

#import <UIKit/UIKit.h>

@interface EXScreenOrientationModule ()

@property (nonatomic, weak) id<UMEventEmitterService> eventEmitter;
@property (nonatomic, assign) bool hasListeners;
@property (nonatomic, assign) UIInterfaceOrientation currentScreenOrientation;

@end

static int INVALID_MASK = 0;
static NSString *defaultAppId = @"bareAppId";

@implementation EXScreenOrientationModule

UM_EXPORT_MODULE(ExpoScreenOrientation);

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setModuleRegistry:(UMModuleRegistry *)moduleRegistry
{
  _eventEmitter = [moduleRegistry getModuleImplementingProtocol:@protocol(UMEventEmitterService)];
  _hasListeners = NO;
  UIDevice *device = [UIDevice currentDevice];
  UIInterfaceOrientation currentDeviceOrientation = [EXScreenOrientationUtilities UIDeviceOrientationToUIInterfaceOrientation:[device orientation]];
  UIInterfaceOrientationMask orientationMask = [self orientationMask];
  
  // this gives the correct information of screen orientation before any rotation or locking
  if ([EXScreenOrientationUtilities doesOrientationMask:orientationMask containOrientation:currentDeviceOrientation]) {
    _currentScreenOrientation = currentDeviceOrientation;
  } else {
    _currentScreenOrientation = [EXScreenOrientationUtilities defaultOrientationForOrientationMask:[self orientationMask]];
  }
}

UM_EXPORT_METHOD_AS(lockAsync,
                    lockAsync:(NSNumber *)orientationLock
                    resolver:(UMPromiseResolveBlock)resolve
                    rejecter:(UMPromiseRejectBlock)reject)
{
  UIInterfaceOrientationMask orientationMask = [EXScreenOrientationUtilities importOrientationLock:orientationLock];
  if (orientationMask == INVALID_MASK) {
    return reject(@"ERR_SCREEN_ORIENTATION_INVALID_ORIENTATION_LOCK", [NSString stringWithFormat:@"Invalid screen orientation lock %@", orientationLock], nil);
  }
  if (![EXScreenOrientationUtilities doesSupportOrientationMask:orientationMask]) {
    return reject(@"ERR_SCREEN_ORIENTATION_UNSUPPORTED_ORIENTATION_LOCK", [NSString stringWithFormat:@"This device does not support this orientation %@", orientationLock], nil);
  }
  [self setOrientationMask:orientationMask];
  [self enforceDesiredDeviceOrientationWithOrientationMask:orientationMask];
  resolve(nil);
}


UM_EXPORT_METHOD_AS(lockPlatformAsync,
                    lockPlatformAsync:(NSArray <NSNumber *> *)allowedOrientations
                    resolver:(UMPromiseResolveBlock)resolve
                    rejecter:(UMPromiseRejectBlock)reject)
{
  // combine all the allowedOrientations into one bitmask
  UIInterfaceOrientationMask allowedOrientationsMask = 0;
  for (NSNumber *allowedOrientation in allowedOrientations) {
    UIInterfaceOrientation orientation = [EXScreenOrientationUtilities importOrientation:allowedOrientation];
    UIInterfaceOrientationMask orientationMask = [EXScreenOrientationUtilities maskFromOrientation:orientation];
    allowedOrientationsMask = allowedOrientationsMask | orientationMask;
  }
  [self setOrientationMask:allowedOrientationsMask];
  [self enforceDesiredDeviceOrientationWithOrientationMask:allowedOrientationsMask];
  resolve(nil);
}

UM_EXPORT_METHOD_AS(getOrientationLockAsync,
                    getOrientationLockAsyncWithResolver:(UMPromiseResolveBlock)resolve
                    rejecter:(UMPromiseRejectBlock)reject)
{
  resolve([EXScreenOrientationUtilities exportOrientationLock:[self orientationMask]]);
}

UM_EXPORT_METHOD_AS(getPlatformOrientationLockAsync,
                    getPlatformOrientationLockAsyncResolver:(UMPromiseResolveBlock)resolve
                    rejecter:(UMPromiseRejectBlock)reject)
{
    UIInterfaceOrientationMask orientationMask = [self orientationMask];
    NSArray *singleOrientations = @[@(UIInterfaceOrientationMaskPortrait),
                                    @(UIInterfaceOrientationMaskPortraitUpsideDown),
                                    @(UIInterfaceOrientationMaskLandscapeLeft),
                                    @(UIInterfaceOrientationMaskLandscapeRight)];
    // If the particular orientation is supported, we add it to the array of allowedOrientations
    NSMutableArray *allowedOrientations = [[NSMutableArray alloc] init];
    for (NSNumber *wrappedSingleOrientation in singleOrientations) {
      UIInterfaceOrientationMask singleOrientationMask = [wrappedSingleOrientation intValue];
      UIInterfaceOrientationMask supportedOrientation = orientationMask & singleOrientationMask;
      if (supportedOrientation == singleOrientationMask) {
        [allowedOrientations addObject:[EXScreenOrientationUtilities exportOrientationLock:singleOrientationMask]];
      }
    }
    resolve(allowedOrientations);
}

UM_EXPORT_METHOD_AS(supportsOrientationLockAsync,
                    supportsOrientationLockAsync:(NSNumber *)orientationLock
                    resolver:(UMPromiseResolveBlock)resolve
                    rejecter:(UMPromiseRejectBlock)reject)
{
  UIInterfaceOrientationMask orientationMask = [EXScreenOrientationUtilities importOrientationLock:orientationLock];
  if (orientationMask == INVALID_MASK) {
    resolve(@NO);
  } else if ([EXScreenOrientationUtilities doesSupportOrientationMask:orientationMask]) {
    resolve(@YES);
  } else {
    resolve(@NO);
  }
}

UM_EXPORT_METHOD_AS(getOrientationAsync,
                    getOrientationAsyncResolver:(UMPromiseResolveBlock)resolve
                    rejecter:(UMPromiseRejectBlock)reject)
{
  resolve([EXScreenOrientationUtilities exportOrientation:_currentScreenOrientation]);
}

- (UIInterfaceOrientationMask)orientationMask
{
  return [[EXScreenOrientationModule sharedRegistry] orientationMaskForAppId:defaultAppId];
}

- (void)setOrientationMask:(UIInterfaceOrientationMask)mask
{
  return [[EXScreenOrientationModule sharedRegistry] setOrientationMask:mask forAppId:defaultAppId];
}

+ (EXScreenOrientationRegistry *)sharedRegistry
{
  return (EXScreenOrientationRegistry *)[UMModuleRegistryProvider getSingletonModuleForClass:[EXScreenOrientationRegistry class]];
}

// Will be called when this module's first listener is added.
- (void)startObserving
{
  if (![[UIDevice currentDevice] isGeneratingDeviceOrientationNotifications]){
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
  }
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleDeviceOrientationChange:)
                                               name:UIDeviceOrientationDidChangeNotification
                                             object:[UIDevice currentDevice]];
  _hasListeners = YES;
}

// Will be called when this module's last listener is removed, or on dealloc.
- (void)stopObserving
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];

  _hasListeners = NO;
}

- (void)handleDeviceOrientationChange:(NSNotification *)notification
{
  UIDevice *device = notification.object;
  UIInterfaceOrientation currentDeviceOrientation = [EXScreenOrientationUtilities UIDeviceOrientationToUIInterfaceOrientation:[device orientation]];
  UIInterfaceOrientationMask orientationMask = [self orientationMask];
  
  // first check: phone only rotates if device orientation is in mask, second check: we should send event only if device didn't rotate to current screen orientation
  if ([EXScreenOrientationUtilities doesOrientationMask:orientationMask containOrientation:currentDeviceOrientation] && _currentScreenOrientation != currentDeviceOrientation) {
    _currentScreenOrientation = currentDeviceOrientation;
    if (_hasListeners) {
      [self handleScreenOrientationChange];
    }
  }
}

- (void)handleScreenOrientationChange
{
  [_eventEmitter sendEventWithName:@"expoDidUpdateDimensions" body:@{
    @"orientation": [EXScreenOrientationUtilities exportOrientation:_currentScreenOrientation],
    @"orientationLock": [EXScreenOrientationUtilities exportOrientationLock:[self orientationMask]]
  }];
}

- (NSArray<NSString *> *)supportedEvents {
  return @[@"expoDidUpdateDimensions", @"expoDidUpdatePhysicalDimensions"];
}

- (void)enforceDesiredDeviceOrientationWithOrientationMask:(UIInterfaceOrientationMask)orientationMask
{
  // if current sreen orientation isn't part of the mask, we have to change orientation for default one included in mask, in order up-left-right-down
  if (![EXScreenOrientationUtilities doesOrientationMask:orientationMask containOrientation:_currentScreenOrientation]) {
    UIInterfaceOrientation newOrientation = [EXScreenOrientationUtilities defaultOrientationForOrientationMask:orientationMask];
    if (newOrientation != UIInterfaceOrientationUnknown) {
      _currentScreenOrientation = newOrientation;
      dispatch_async(dispatch_get_main_queue(), ^{
        [[UIDevice currentDevice] setValue:@(newOrientation) forKey:@"orientation"];
        // screen orientation changed so we send event (notification isn't triggered when manually changing orienatation)
        [self handleScreenOrientationChange];
        [UIViewController attemptRotationToDeviceOrientation];
      });
    }
  }
}

@end
