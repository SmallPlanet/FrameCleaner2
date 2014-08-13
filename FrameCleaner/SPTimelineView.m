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

- (void) removeZone:(id)object {
    if ([self.zones containsObject:object]) {
        [self.zones removeObject:object];
        if ([self.subviews containsObject:object]) {
            [object removeFromSuperview];
        }
        [[self.document undoManager] registerUndoWithTarget:self selector:@selector(addZone:) object:object];
        self.needsDisplay = YES;
    }
}

- (void) addZone:(id)object {
    if (![self.zones containsObject:object]) {
        [self.zones addObject:object];
        if (![self.subviews containsObject:object]) {
            [self addSubview:object];
        }
        [[self.document undoManager] registerUndoWithTarget:self selector:@selector(removeZone:) object:object];
        self.needsDisplay = YES;
    }
}

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
        
        [self addZone:newZone];
        newZone = nil;
        eventState = idle;
    }
    [self setCurrentFrameIndex:-1];
}

- (void) reset {
    [self.zones makeObjectsPerformSelector: @selector(removeFromSuperview)];
    [self.zones removeAllObjects];
    self.needsDisplay = YES;
}

- (NSArray *) zonesArrayForPlist {
    NSMutableArray *array = [NSMutableArray array];
    for (SPBorderedView *zone in self.zones) {
        NSRect rect = zone.frame;
        rect.origin.x /= self.frame.size.width;
        rect.origin.y /= self.frame.size.height;
        rect.size.width /= self.frame.size.width;
        rect.size.height /= self.frame.size.height;
        [array addObject:NSStringFromRect(rect)];
    }
    return array;
}

- (void) setZonesArrayFromPlist:(NSArray *)array {
    if (!array) {
        return;
    }
    [self reset];
    for (NSString *zoneString in array) {
        NSRect rect = NSRectFromString(zoneString);
        rect.origin.x *= self.frame.size.width;
        rect.origin.y *= self.frame.size.height;
        rect.size.width *= self.frame.size.width;
        rect.size.height *= self.frame.size.height;
        SPBorderedView *zoneView = [self addRegionWithFrame:rect];
        [self.zones addObject:zoneView];
        for (FCImage *frame in self.frames) {
            CGFloat x = [self xPositionForFrameIndex:[self.frames indexOfObject:frame]];
            if (x >= zoneView.frame.origin.x && x <= zoneView.frame.origin.x+zoneView.frame.size.width) {
                [zoneView.data addObject:frame];
            }
        }
    }
    [self setCurrentFrameIndex:-1];
}

- (BOOL) acceptsFirstResponder {
    return YES;
}

#pragma mark - save/load

- (NSMutableDictionary *) dataDictionary {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
//    for ()
    return data;
}

- (void) loadWithDataDictionary:(NSDictionary *)data {
    
}

@end
