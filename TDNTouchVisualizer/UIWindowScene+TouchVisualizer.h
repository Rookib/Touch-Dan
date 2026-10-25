//
//  UIWindowScene+TouchVisualizer.h
//  TDNTouchVisualizer
//
//  Created by Leo Natan on 3/24/21.
//

#import <TDNTouchVisualizer/TDNTouchVisualizer.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((visibility("hidden")))
@interface UIWindowScene (TDNTouchVisualizer)

@property(nonatomic, assign) BOOL tdn_touchVisualizerEnabled;
@property(nonatomic, strong, readonly) TDNTouchVisualizerWindow *tdn_touchVisualizerWindow;

@end

NS_ASSUME_NONNULL_END
