//
//  SPRegionsView.m
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/9/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import "SPRegionsView.h"

@implementation SPRegionsView

- (void) mouseDown:(NSEvent *)theEvent {
    NSLog(@"Boom");
}

- (void)reset {
    [self.regions removeAllObjects];
    for (NSView *view in self.subviews) {
        [view removeFromSuperview];
    }
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
