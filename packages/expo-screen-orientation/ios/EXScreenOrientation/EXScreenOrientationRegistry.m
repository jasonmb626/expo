// Copyright 2019-present 650 Industries. All rights reserved.

#import <EXScreenOrientation/EXScreenOrientationRegistry.h>
#import <UMCore/UMDefines.h>

@interface EXScreenOrientationRegistry ()

@property (atomic, strong) NSMutableDictionary<NSString *, NSNumber *> *orientationMap;

@end

@implementation EXScreenOrientationRegistry

UM_REGISTER_SINGLETON_MODULE(EXScreenOrientationRegistry)


- (instancetype)init {
  if (self = [super init]) {
    _orientationMap = [NSMutableDictionary new];
  }
  return self;
}

- (void)setOrientationMask:(UIInterfaceOrientationMask)orientationMask
          forAppId:(NSString *)appId
{
  _orientationMap[appId] = @(orientationMask);
}

- (UIInterfaceOrientationMask)orientationMaskForAppId:(NSString *)appId
{
  if (!_orientationMap[appId]) {
    return UIInterfaceOrientationMaskAllButUpsideDown;
  }
  return [_orientationMap[appId] unsignedIntegerValue];
}

- (BOOL)doesKeyExistForAppId:(NSString *)appId
{
  if (!_orientationMap[appId]) {
    return NO;
  }
  return YES;
}
 
@end
