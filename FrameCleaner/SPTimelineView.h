//
//  SPTimelineView.h
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/28/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FCImage.h"

@interface SPTimelineView : NSView

@property (strong) NSMutableArray *frames;
@property (assign) CGFloat maxDiff;

- (void)setFCImageFrames:(NSMutableArray *)newValue;

@end
