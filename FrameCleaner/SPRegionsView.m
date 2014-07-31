//
//  SPRegionsView.m
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/9/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import "SPRegionsView.h"
#import "SPBorderedView.h"
#import "SPDocument.h"

@implementation SPRegionsView

- (void) optimize {
    NSMutableArray *trashBin = [NSMutableArray array];
    NSMutableArray *sortedRegions = [[self.regions sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSRect r1 = [obj1 frame];
        NSRect r2 = [obj2 frame];
        CGFloat a1 = r1.size.width * r1.size.height;
        CGFloat a2 = r2.size.width * r2.size.height;
        CGFloat diff = a1 - a2;
        return (diff < 0 ? NSOrderedAscending : (diff > 0 ? NSOrderedDescending : NSOrderedSame));
    }] mutableCopy];
    
    // remove regions completely contained in other regions
    for (SPBorderedView *region1 in sortedRegions) {
        CGRect r1 = NSRectToCGRect(region1.frame);
        for (SPBorderedView *region2 in sortedRegions) {
            if (region1 != region2 && ![trashBin containsObject:region1] && ![trashBin containsObject:region2]) {
                CGRect r2 = NSRectToCGRect(region2.frame);
                if (CGRectContainsRect(r2, r1)) {
                    [trashBin addObject:region1];
                    break;
                }
            }
        }
    }
    for (SPRegionsView *region in trashBin) {
        [region removeFromSuperview];
        [self.regions removeObject:region];
        [sortedRegions removeObject:region];
    }
    [trashBin removeAllObjects];
    
    // reduce regions with two points in another region
    for (SPBorderedView *region1 in sortedRegions) {
        for (SPBorderedView *region2 in sortedRegions) {
            if (region1 != region2 && [region1 overlapCount:region2] == 2) {
                [region1 reduceIfOverlaps:region2];
            }
        }
    }
    
    // should the regions pass through a difference-point reduction again?
    
    // optimize for 1 corner intersections
    for (SPBorderedView *region1 in sortedRegions) {
        for (SPBorderedView *region2 in sortedRegions) {
            if (region1 != region2 && [region2 overlapCount:region1] == 1) {
                NSRect newFrame = [region2 splitByRemovingRect:region1.frame];
                if (newFrame.origin.x > -1) {
                    [self addRegionWithFrame:newFrame];
//                    SPBorderedView *newRegion = [self addRegionWithFrame:newFrame];
//                    newRegion.layer.borderColor = [NSColor greenColor].CGColor;
//                    region1.layer.borderColor = [NSColor purpleColor].CGColor;
                }
            }
        }
    }
    
}


#pragma mark -

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
            [self addRegion:regionView];
        }
    }
}

- (void) addRegion:(SPBorderedView *)region {
    if (![self.regions containsObject:region]) {
        [self addSubview:region];
        [self.regions addObject:region];
        [[self.document undoManager] registerUndoWithTarget:self selector:@selector(removeRegion:) object:region];
    }
}

- (void) removeRegion:(SPBorderedView *)region {
    if ([self.regions containsObject:region]) {
        [region removeFromSuperview];
        [self.regions removeObject:region];
        [[self.document undoManager] registerUndoWithTarget:self selector:@selector(addRegion:) object:region];
    }
}

- (SPBorderedView *) addRegionWithFrame:(NSRect)frame {
    SPBorderedView *newRegion = [[SPBorderedView alloc] initWithFrame:frame];
    [self addRegion:newRegion];
    return newRegion;
}

#pragma mark -

- (void) mouseDown:(NSEvent *)theEvent {
    originalOrigin = [self convertPoint:theEvent.locationInWindow fromView:nil];
    SPBorderedView *subview = [self addRegionWithFrame:NSMakeRect(originalOrigin.x, originalOrigin.y, 1, 1)];
    activeView = subview;
}

- (void) mouseDragged:(NSEvent *)theEvent {
    if (activeView) {
        NSPoint liv = [self convertPoint:theEvent.locationInWindow fromView:nil];
        CGRect r1 = CGRectMake(originalOrigin.x, originalOrigin.y, 1, 1);
        CGRect r2 = CGRectMake(liv.x, liv.y, 1, 1);
        CGRect frameRect = CGRectUnion(r1, r2);
        if (frameRect.origin.x < 0) {
            frameRect.size.width += frameRect.origin.x;
            frameRect.origin.x = 0;
        }
        if (frameRect.origin.x + frameRect.size.width > self.frame.size.width) {
            frameRect.size.width = self.frame.size.width - frameRect.origin.x;
        }
        if (frameRect.origin.y < 0) {
            frameRect.size.height += frameRect.origin.y;
            frameRect.origin.y = 0;
        }
        if (frameRect.origin.y + frameRect.size.height > self.frame.size.height) {
            frameRect.size.height = self.frame.size.height - frameRect.origin.y;
        }
        activeView.frame = NSRectFromCGRect(frameRect);
    }
}

- (void) mouseUp:(NSEvent *)theEvent {
    
}

- (void)reset {
    [self.regions removeAllObjects];
    [self.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.regions = [NSMutableArray array];

        CALayer *layer = [CALayer layer];
        layer.frame = self.frame;
        layer.borderColor = [NSColor colorWithCalibratedWhite:0.4 alpha:0.5].CGColor;
        layer.borderWidth = 1.f;
        self.layer = layer;
        [self setWantsLayer:YES];
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
