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

- (CGFloat) xPositionForFrameIndex:(NSInteger)index {
    return OFFSET + (self.frame.size.width - 2*OFFSET) / self.frames.count * index;
}

- (BOOL) isFrameInZone:(FCImage *)frame {
    for (SPBorderedView *zone in self.zones) {
        if ([zone.data containsObject:frame]) {
            return YES;
        }
    }
    return NO;
}

- (void)drawTimeline {
    if (!self.frames) {
        return;
    }
    
    [NSBezierPath setDefaultLineWidth:2.f];
    NSColor *defaultColor = [NSColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    NSColor *highlightColor = [NSColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0];
    NSColor *zoneColor = [NSColor colorWithRed:0.2 green:0.2 blue:0.9 alpha:1.0];
    NSColor *zoneNewColor = [NSColor colorWithRed:0.2 green:0.9 blue:0.2 alpha:1.0];
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
        if (currentFrameIndex == [self.frames indexOfObject:frame]) {
            [highlightColor setStroke];
        } else if (x-OFFSET >= zoneRange.x && x-OFFSET <= zoneRange.y) {
            [zoneNewColor setStroke];
        } else {
            if ([self isFrameInZone:frame]) {
                [zoneColor setStroke];
            } else {
                [defaultColor setStroke];
            }
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

- (SPBorderedView *) addRegionWithFrame:(NSRect)frame {
    SPBorderedView *newRegion = [[SPBorderedView alloc] initWithFrame:frame];
    [self addSubview:newRegion];
    return newRegion;
}

- (CGFloat) midpointBetweenNearestFramesForX:(CGFloat)x {
    return x;
}

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
    originalOrigin = [self processMouseEvent:theEvent];
    currentPosition = originalOrigin;
    if( NSShiftKeyMask & [NSEvent modifierFlags] ){
        eventState = creatingZone;
        CGFloat x = [self midpointBetweenNearestFramesForX:originalOrigin.x];
        NSRect zoneRect = NSMakeRect(x,self.frame.size.height*0.4,1,self.frame.size.height*0.2);
        newZone = [self addRegionWithFrame:zoneRect];
    }
}

- (void) mouseDragged:(NSEvent *)theEvent {
    currentPosition = [self processMouseEvent:theEvent];
    if (eventState == creatingZone) {
        NSRect zoneRect = newZone.frame;
        if (zoneRect.origin.x < currentPosition.x) {
            zoneRect.size.width = currentPosition.x - zoneRect.origin.x;
        } else {
            zoneRect.size.width = zoneRect.origin.x - currentPosition.x;
            zoneRect.origin.x = currentPosition.x;
        }
        newZone.frame = zoneRect;
    }
}

- (void) mouseUp:(NSEvent *)theEvent {
    if (eventState == creatingZone) {
        [newZone.data removeAllObjects];
        for (FCImage *frame in self.frames) {
            CGFloat x = [self xPositionForFrameIndex:[self.frames indexOfObject:frame]];
            if (x >= newZone.frame.origin.x && x <= newZone.frame.origin.x+newZone.frame.size.width) {
                [newZone.data addObject:frame];
            }
        }
        
        [self.zones addObject:newZone];
        newZone = nil;
        eventState = idle;
    }
    [self setCurrentFrameIndex:-1];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

@end
