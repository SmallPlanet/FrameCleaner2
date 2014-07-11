//
//  SPBackgroundView.m
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/11/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import "SPBackgroundView.h"

#if (NSAppKitVersionNumber > NSAppKitVersionNumber10_9)

@implementation SPBackgroundView

@end


#else


// Mavericks and before -- just an NSView
@implementation SPBackgroundView


@end

#endif