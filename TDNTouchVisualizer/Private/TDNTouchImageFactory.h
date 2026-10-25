//
//  TDNTouchImageFactory.h
//  TDNTouchVisualizer
//
//  Created by Joseph Blau on 12/2/17.
//  Copyright © 2017 conopsys. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TDNTouchConfig;

__attribute__((visibility("hidden")))
@interface TDNTouchImageFactory : NSObject

+ (nonnull UIImage *)imageWithTouchConfig:(nonnull TDNTouchConfig *)touchConfig;

- (nonnull instancetype)init NS_UNAVAILABLE;

@end
