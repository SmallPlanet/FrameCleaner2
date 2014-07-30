//
//  SPTimelineView.m
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/28/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import "SPTimelineView.h"
#import "SPDocument.h"

#define OFFSET 5.0

@implementation SPTimelineView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.zones = [NSMutableArray array];
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

- (void) setCurrentFrameIndex:(NSInteger)index {
    currentFrameIndex = index;
    self.needsDisplay = YES;
}

- (void)drawTimeline {
    if (!self.frames) {
        return;
    }
    
    [NSBezierPath setDefaultLineWidth:2.f];
    NSColor *defaultColor = [NSColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    NSColor *highlightColor = [NSColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0];
    NSColor *zoneColor = [NSColor colorWithRed:0.2 green:0.9 blue:0.2 alpha:1.0];
    CGFloat width = self.frame.size.width - 2*OFFSET;
    CGFloat height = self.frame.size.height - 2*OFFSET;
    CGFloat x = OFFSET;
    CGFloat scale = height / self.maxDiff;
    CGPoint zoneRange = CGPointZero;
    if (eventState == creatingZone) {
        zoneRange.x = (originalOrigin.x < currentPosition.x ? originalOrigin.x : currentPosition.x);
        zoneRange.y = (originalOrigin.x > currentPosition.x ? originalOrigin.x : currentPosition.x);
    }
    for (FCImage *frame in self.frames) {
        if (frame.inZone || (x-OFFSET >= zoneRange.x && x-OFFSET <= zoneRange.y)) {
            [zoneColor setStroke];
        } else {
            (currentFrameIndex == [self.frames indexOfObject:frame] ? [highlightColor setStroke] : [defaultColor setStroke]);
        }
        CGFloat y = OFFSET + frame.diffCount * scale;
        [NSBezierPath strokeLineFromPoint:NSMakePoint(x, OFFSET) toPoint:NSMakePoint(x, y)];
        x+= width / self.frames.count;
    }
    
 }

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    [self drawTimeline];
}

#pragma mark -

- (NSPoint) processMouseEvent:(NSEvent *)theEvent {
    NSPoint point = [self convertPoint:theEvent.locationInWindow fromView:nil];
    CGFloat betweenFrames = (self.frame.size.width - 2*OFFSET) / self.frames.count;
    NSInteger closestFrameIndex = (point.x - OFFSET + betweenFrames/2.f) / (self.frame.size.width-2*OFFSET) * self.frames.count;
    if (closestFrameIndex != currentFrameIndex) {
        [self setCurrentFrameIndex:closestFrameIndex];
        [self.document showFrameAtIndex:closestFrameIndex];
    }
    return point;
}

- (void) mouseDown:(NSEvent *)theEvent {
    if( NSShiftKeyMask & [NSEvent modifierFlags] ){
        eventState = creatingZone;
    }
    originalOrigin = [self processMouseEvent:theEvent];
    currentPosition = originalOrigin;
}

- (void) mouseDragged:(NSEvent *)theEvent {
    currentPosition = [self processMouseEvent:theEvent];
}

- (void) mouseUp:(NSEvent *)theEvent {
    eventState = idle;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

@end
