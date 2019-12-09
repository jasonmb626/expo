// Copyright 2019-present 650 Industries. All rights reserved.

#import <Foundation/Foundation.h>
#import <EXScreenOrientation/EXScreenOrientationUtilities.h>

#import <sys/utsname.h>

static UIInterfaceOrientationMask INVALID_MASK = 0;

@implementation EXScreenOrientationUtilities

# pragma mark - helpers

+ (BOOL)doesSupportOrientationMask:(UIInterfaceOrientationMask)orientationMask
{
  if ((UIInterfaceOrientationMaskPortraitUpsideDown & orientationMask) // UIInterfaceOrientationMaskPortraitUpsideDown is part of orientationMask
      && ![EXScreenOrientationUtilities doesDeviceSupportOrientationPortraitUpsideDown])
  {
    // device does not support UIInterfaceOrientationMaskPortraitUpsideDown and it was requested via orientationMask
    return FALSE;
  }
  
  return TRUE;
}

+ (BOOL)doesDeviceSupportOrientationPortraitUpsideDown
{
  struct utsname systemInfo;
  uname(&systemInfo);
  NSString *deviceIdentifier = [NSString stringWithCString:systemInfo.machine
                                                  encoding:NSUTF8StringEncoding];
  return ![EXScreenOrientationUtilities doesDeviceHaveNotch:deviceIdentifier];
}

+ (BOOL)doesDeviceHaveNotch:(NSString *)deviceIdentifier
{
  NSArray<NSString *> *devicesWithNotchIdentifiers = @[
                                                       @"iPhone10,3", // iPhoneX
                                                       @"iPhone10,6", // iPhoneX
                                                       @"iPhone11,2", // iPhoneXs
                                                       @"iPhone11,6", // iPhoneXsMax
                                                       @"iPhone11,4", // iPhoneXsMax
                                                       @"iPhone11,8", // iPhoneXr
                                                       ];
  NSArray<NSString *> *simulatorsIdentifiers = @[
                                                 @"i386",
                                                 @"x86_64",
                                                 ];
  
  if ([devicesWithNotchIdentifiers containsObject:deviceIdentifier]) {
    return YES;
  }
  
  if ([simulatorsIdentifiers containsObject:deviceIdentifier]) {
    return [self doesDeviceHaveNotch:[[[NSProcessInfo processInfo] environment] objectForKey:@"SIMULATOR_MODEL_IDENTIFIER"]];
  }
  return NO;
}

+ (UIInterfaceOrientationMask)maskFromOrientation:(UIInterfaceOrientation)orientation
{
  switch (orientation) {
    case UIInterfaceOrientationPortrait:
      return UIInterfaceOrientationMaskPortrait;
    case UIInterfaceOrientationPortraitUpsideDown:
      return UIInterfaceOrientationMaskPortraitUpsideDown;
    case UIInterfaceOrientationLandscapeLeft:
        return UIInterfaceOrientationMaskLandscapeLeft;
    case UIInterfaceOrientationLandscapeRight:
      return UIInterfaceOrientationMaskLandscapeRight;
    default:
      return INVALID_MASK;
  }
}

+ (UIInterfaceOrientation)UIDeviceOrientationToUIInterfaceOrientation:(UIDeviceOrientation)deviceOrientation
{
   switch (deviceOrientation) {
     case UIDeviceOrientationPortrait:
       return UIInterfaceOrientationPortrait;
     case UIDeviceOrientationPortraitUpsideDown:
       return UIInterfaceOrientationPortraitUpsideDown;
     // UIDevice and UIInterface landscape orientations are switched
     case UIDeviceOrientationLandscapeLeft:
       return UIInterfaceOrientationLandscapeRight;
     case UIDeviceOrientationLandscapeRight:
       return UIInterfaceOrientationLandscapeLeft;
     default:
       return UIInterfaceOrientationUnknown;
   }
}

+ (BOOL)doesOrientationMask:(UIInterfaceOrientationMask)orientationMask containOrientation:(UIInterfaceOrientation)orientation
{
  // This is how the mask is created from the orientation
  UIInterfaceOrientationMask maskFromOrientation = (1 << orientation);
  return (maskFromOrientation & orientationMask);
}

+ (UIInterfaceOrientation)defaultOrientationForOrientationMask:(UIInterfaceOrientationMask)orientationMask
{
  UIInterfaceOrientation defaultOrientation = UIInterfaceOrientationUnknown;
  if (UIInterfaceOrientationMaskPortrait & orientationMask) {
    defaultOrientation = UIInterfaceOrientationPortrait;
  } else if (UIInterfaceOrientationMaskLandscapeLeft & orientationMask) {
    defaultOrientation = UIInterfaceOrientationLandscapeLeft;
  } else if (UIInterfaceOrientationMaskLandscapeRight & orientationMask) {
    defaultOrientation = UIInterfaceOrientationLandscapeRight;
  } else if (UIInterfaceOrientationMaskPortraitUpsideDown & orientationMask) {
    defaultOrientation = UIInterfaceOrientationPortraitUpsideDown;
  }
  return defaultOrientation;
}

# pragma mark - import/export

+ (UIInterfaceOrientationMask)importOrientationLock:(NSNumber *)orientationLock
{
  static NSDictionary *orientationLockMap = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    orientationLockMap = @{
      @0 : @(UIInterfaceOrientationMaskAllButUpsideDown),
      @1 : @(UIInterfaceOrientationMaskAll),
      @2 : @(UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown),
      @3 : @(UIInterfaceOrientationMaskPortrait),
      @4 : @(UIInterfaceOrientationMaskPortraitUpsideDown),
      @5 : @(UIInterfaceOrientationMaskLandscape),
      @6 : @(UIInterfaceOrientationMaskLandscapeLeft),
      @7 : @(UIInterfaceOrientationMaskLandscapeRight),
      @10: @(UIInterfaceOrientationMaskAllButUpsideDown)
    };
  });
  
  return [orientationLockMap[orientationLock] integerValue] ?: INVALID_MASK;
}

+ (NSNumber *)exportOrientationLock:(UIInterfaceOrientationMask)orientationMask
{
  static NSDictionary *orientationLockMap = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    orientationLockMap = @{
      @(UIInterfaceOrientationMaskAllButUpsideDown)   : @0,
      @(UIInterfaceOrientationMaskAll)                : @1,
      @(UIInterfaceOrientationMaskPortrait
      | UIInterfaceOrientationMaskPortraitUpsideDown) : @2,
      @(UIInterfaceOrientationMaskPortrait)           : @3,
      @(UIInterfaceOrientationMaskPortraitUpsideDown) : @4,
      @(UIInterfaceOrientationMaskLandscape)          : @5,
      @(UIInterfaceOrientationMaskLandscapeLeft)      : @6,
      @(UIInterfaceOrientationMaskLandscapeRight)     : @7,
      @(UIInterfaceOrientationMaskAllButUpsideDown)   : @10
    };
  });
  
  return orientationLockMap[@(orientationMask)] ?: @(8);
}

+ (NSNumber *)exportOrientation:(UIInterfaceOrientation)orientation
{
  static NSDictionary *orientationMap = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    orientationMap = @{
      @(UIInterfaceOrientationPortrait)           : @1,
      @(UIInterfaceOrientationPortraitUpsideDown) : @2,
      @(UIInterfaceOrientationLandscapeLeft)      : @3,
      @(UIInterfaceOrientationLandscapeRight)     : @4,
    };
  });
  
  return orientationMap[@(orientation)] ?: @(UIInterfaceOrientationUnknown);
}

+ (UIInterfaceOrientation)importOrientation:(NSNumber *)orientation
{
  static NSDictionary *orientationMap = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    orientationMap = @{
      @1 : @(UIInterfaceOrientationPortrait),
      @2 : @(UIInterfaceOrientationPortraitUpsideDown),
      @3 : @(UIInterfaceOrientationLandscapeLeft),
      @4 : @(UIInterfaceOrientationLandscapeRight),
    };
  });
  
  return [orientationMap[orientation] intValue] ?: UIInterfaceOrientationUnknown;
}

@end
