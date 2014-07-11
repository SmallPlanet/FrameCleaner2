//
//  SPBackgroundView.h
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/11/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#if (NSAppKitVersionNumber > NSAppKitVersionNumber10_9)

@interface SPBackgroundView : NSVisualEffectView



@end

#else

@interface SPBackgroundView : NSView



@end



#endif

