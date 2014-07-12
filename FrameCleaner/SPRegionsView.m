//
//  SPRegionsView.m
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/9/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import "SPRegionsView.h"
#import "SPBorderedView.h"

@implementation SPRegionsView

- (NSArray *) regionsArrayForPlist {
    NSMutableArray *array = [NSMutableArray array];
    for (SPBorderedView *region in self.regions) {
        [array addObject:NSStringFromRect(region.frame)];
    }
    return array;
}

- (void) setRegionsArrayFromPlist:(NSArray *)array {
    [self reset];
    for (NSString *regionString in array) {
        SPBorderedView *regionView = [[SPBorderedView alloc] initWithFrame:NSRectFromString(regionString)];
        if (regionView) {
            [self addSubview:regionView];
            [self.regions addObject:regionView];
        }
    }
}

#pragma mark -

- (void) mouseDown:(NSEvent *)theEvent {
    NSLog(@"Boom");
    originalOrigin = [self convertPoint:theEvent.locationInWindow fromView:nil];
    SPBorderedView *subview = [[SPBorderedView alloc] initWithFrame:NSMakeRect(originalOrigin.x, originalOrigin.y, 1, 1)];
    activeView = subview;
    [self addSubview:subview];
}

- (void) mouseDragged:(NSEvent *)theEvent {
    if (activeView) {
        NSPoint liv = [self convertPoint:theEvent.locationInWindow fromView:nil];
        CGRect r1 = CGRectMake(originalOrigin.x, originalOrigin.y, 1, 1);
        CGRect r2 = CGRectMake(liv.x, liv.y, 1, 1);
        CGRect frameRect = CGRectUnion(r1, r2);
        activeView.frame = NSRectFromCGRect(frameRect);
    }
}

- (void) mouseUp:(NSEvent *)theEvent {
    if (activeView) {
        [self.regions addObject:activeView];
    }
}

- (void)reset {
    [self.regions removeAllObjects];
    [self.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.regions = [NSMutableArray array];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

@end
