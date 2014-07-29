//
//  SPTimelineView.h
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/28/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FCImage.h"
@class SPDocument;

@interface SPTimelineView : NSView {
    NSInteger currentFrameIndex;
    NSPoint originalOrigin;
}

@property (strong) NSMutableArray *frames;
@property (assign) CGFloat maxDiff;
@property (assign) SPDocument *document;

- (void)setFCImageFrames:(NSMutableArray *)newValue;
- (void) setCurrentFrameIndex:(NSInteger)index;

@end
