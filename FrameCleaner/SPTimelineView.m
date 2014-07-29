//
//  SPTimelineView.m
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/28/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import "SPTimelineView.h"

@implementation SPTimelineView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)setFCImageFrames:(NSMutableArray *)newValue {
    self.frames = newValue;
    self.maxDiff = 0.f;
    for (FCImage *frame in self.frames) {
        if (frame.diffCount > self.maxDiff) {
            self.maxDiff = frame.diffCount;
        }
    }
    self.needsDisplay = YES;
}

- (void)drawTimeline {
    if (!self.frames) {
        return;
    }
    
//    NSBezierPath *bPath = [NSBezierPath bezierPath];
    [NSBezierPath setDefaultLineWidth:2.f];
    NSColor *tColor = [NSColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    [tColor setStroke];
//    bPath.lineWidth = 2.0;
    CGFloat offset = 5.0;
    CGFloat width = self.frame.size.width - 2*offset;
    CGFloat height = self.frame.size.height - 2*offset;
    CGFloat x = offset;
    CGFloat scale = height / self.maxDiff;
    for (FCImage *frame in self.frames) {
        CGFloat y = offset + frame.diffCount * scale;
        [NSBezierPath strokeLineFromPoint:NSMakePoint(x, offset) toPoint:NSMakePoint(x, y)];
        NSLog(@"x,y = %.1f, %.1f", x, y);
        x+= width / self.frames.count;
    }
    
 }

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    [self drawTimeline];
}

@end
